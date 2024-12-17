import torch
import numpy as np
import pickle
import pandas as pd
from scipy.stats import sem
import matplotlib.pyplot as plt
from utils.load_utils import load_data
from utils.load_agents import load_policy, load_FQN
from estimator import get_final_estimator
from scipy.stats import pearsonr


def mortality_expectedReturn(data, agent, index, state_mode="raw", reward_mode="intermediate", cl=None):
    estimator = get_final_estimator(agent, state_mode, reward_mode, index_of_split=index, confidence_level=cl)
    FQEmodel = estimator.fqe_policy

    model_eval = FQEmodel

    # evaluating the mortality
    physician_performance = []

    counter = 0
    observatins = []
    mortalities = []
    for episode in data.episodes:
        q_val = []
        for index in range(len(episode.actions)):
            action = episode.actions[index]
            observation = episode.observations[index]
            reward = episode.rewards[index]
        if -1.0 in episode.rewards:
            mortalities.append(1)
        else:
            mortalities.append(0)

        # actions = model_eval.select_action([observation])

        observatins.append(observation[0])
        values = model_eval.get_q_values(torch.tensor([observation], device="cuda", dtype=torch.float32)).squeeze()[
            action].item()
        # values = model_eval.get_q_values(torch.tensor(observation,device="cuda",dtype=torch.float32))[action].item()

        q_val.append(values)
        counter = counter + len(episode.actions)
        physician_performance.append(q_val)

    phys_score = 0.0
    for arr in physician_performance:
        phys_score += np.mean(arr)
    phys_score /= len(physician_performance)

    all_phys_performance = []
    for arr in physician_performance:
        all_phys_performance.extend(arr)

    pp = pd.Series(all_phys_performance)
    phys_df = pd.DataFrame(pp)

    mortality = []
    for mort in mortalities:
        mortality.append(mort)

    phys_df['mort'] = mortality
    return phys_df


def sliding_mean(data_array, window=2):
    new_list = []
    for i in range(len(data_array)):
        indices = range(max(i - window + 1, 0),
                        min(i + window + 1, len(data_array)))
        avg = 0
        for j in indices:
            avg += data_array[j]
        avg /= float(len(indices))
        new_list.append(avg)
    return np.array(new_list)


def plotting(phys_df, output_name, colour):
    bin_medians = []
    mort = []
    mort_std = []
    i = -1
    while i <= 1.20:
        count = phys_df.loc[(phys_df[0] > i - 0.1) & (phys_df[0] < i + 0.1)]
        try:
            res = sum(count['mort']) / float(len(count))
            if len(count) >= 2:
                bin_medians.append(i)
                mort.append(res)
                mort_std.append(sem(count['mort']))
        except ZeroDivisionError:
            pass
        i += 0.1

    plt.figure(figsize=(6, 4.5))
    plt.plot(bin_medians, sliding_mean(mort), color=colour[0])
    plt.fill_between(bin_medians, sliding_mean(mort) - 1 * sliding_mean(mort_std),
                     sliding_mean(mort) + 1 * sliding_mean(mort_std), color=colour[1])
    plt.grid()
    plt.xticks(np.arange(-1, 1.5))
    r = [float(i) / 10 for i in range(0, 11, 1)]
    _ = plt.yticks(r, fontsize=13)
    _ = plt.title(output_name, fontsize=17.5)
    _ = plt.ylabel("Proportion Mortality", fontsize=15)
    _ = plt.xlabel("Expected Return", fontsize=15)

    plt.savefig(output_name)
    plt.show()


def main(agent):
    df_train = pd.DataFrame()
    df_test = pd.DataFrame()
    n_runs = 1
    state_mode = "ood"
    reward_mode = "ood"
    cl = 0.85
    for i in range(n_runs):
        train_data, test_data, _, _ = load_data(state_mode, reward_mode, i)
        df_train = df_train.append(
            mortality_expectedReturn(train_data, agent, i, state_mode=state_mode, reward_mode=reward_mode, cl=cl))

    for i in range(n_runs):
        df_test = df_test.append(
            mortality_expectedReturn(test_data, agent, i, state_mode=state_mode, reward_mode=reward_mode, cl=cl))

    if agent == "CQL":
        colour = ['b', 'lightblue']
    else:
        colour = ['g', 'lightgreen']

    plotting(df_train, "Mortality vs Expected Return - DeepVent", colour)
    plotting(df_test, "Mortality vs Expected Return - DeepVent OOD", colour)


def calculate_physician_q_values(data):
    all_q_values = []
    policy_q_values = []
    gamma = 0.65
    # Loop through each episode
    for episode in data.episodes:
        q_values = [0] * len(episode.rewards)  # Initialize Q-values with zeros
        future_q_value = 0  # Initialize future Q-value for the final state

        # Loop backward through each time step in the episode
        for index in reversed(range(len(episode.rewards))):
            # Update Q-value based on the reward at the current step and future Q-value
            future_q_value = episode.rewards[index] + gamma * future_q_value
            q_values[index] = future_q_value  # Store the Q-value for the current state

        all_q_values += q_values
    return np.array(all_q_values).flatten()

def calculate_mortality(data):
    mortality=[]
    # Loop through each episode
    for episode in data.episodes:
        mort= 1 if -1==episode.rewards[-1] else 0
        # Loop backward through each time step in the episode
        for index in reversed(range(len(episode.rewards))):
            mortality.append(mort)
    return mortality

def get_policy_q_values(policy,data):
    all_q_values = []
    for episode in data.episodes:
        for index in reversed(range(len(episode.rewards))):
            observation = episode.observations[index]
            action=episode.actions[index]
            values = policy.get_q_values(torch.tensor([observation], device="cuda", dtype=torch.float32)).squeeze()[
                action].item()
            all_q_values.append(values)
    return all_q_values


def compute_q_value_mortality_correlation():
    agents = ["ConformalDQN", "CQL", "DQN", ]
    train_results = {key: [] for key in agents}
    test_results = {key: [] for key in agents}
    val_results = {key: [] for key in agents}

    df_train = pd.DataFrame()
    df_val = pd.DataFrame()
    df_test = pd.DataFrame()
    n_runs = 5
    state_mode = "raw"
    reward_mode = "intermediate"
    cl = 0.85
    for agent in agents:
        train_correlations = []
        test_correlations = []
        val_correlations = []
        print(f"Computing for {agent}")
        for i in range(n_runs):
            train_data, test_data, val_data, _ = load_data(state_mode, reward_mode, i)
            df_train = df_train.append(
                mortality_expectedReturn(train_data, agent, i, state_mode=state_mode, reward_mode=reward_mode, cl=cl))
            df_test = df_test.append(
                mortality_expectedReturn(test_data, agent, i, state_mode=state_mode, reward_mode=reward_mode, cl=cl))
            df_val = df_val.append(
                mortality_expectedReturn(val_data, agent, i, state_mode=state_mode, reward_mode=reward_mode, cl=cl))
            train_correlations.append(pearsonr(df_train[0], df_train['mort'])[0])
            test_correlations.append(pearsonr(df_test[0], df_test['mort'])[0])
            val_correlations.append(pearsonr(df_val[0], df_val['mort'])[0])
        train_results[agent] = train_correlations
        test_results[agent] = test_correlations
        val_results[agent] = val_correlations

    for k in train_results.keys():
        print(f"--------{k}--------")
        print(f"Train results for {k}: {np.mean(train_results[k])} , {np.std(train_results[k])}")
        print(f"Test results for {k}: {np.mean(test_results[k])} , {np.std(test_results[k])}")
        print(f"Test results for {k}: {np.mean(val_results[k])} , {np.std(val_results[k])}")


compute_q_value_mortality_correlation()


