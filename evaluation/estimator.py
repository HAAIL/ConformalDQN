import numpy as np
import itertools
from collections import Counter
from utils.load_utils import load_data
from utils.buffer import get_buffers,prepare_buffer
from utils.load_agents import load_policy,load_FQN
from models.conformal_Predictor import ConformalPredictor
import torch

ACTION_DICT                 = {
                                'peep' : [5, 7, 9, 11, 13, 15, 1000000000],
                                'fio2' : [30, 35, 40, 45, 50, 55, 1000000000],
                                'adjusted_tidal_volume' : [0, 5, 7.5, 10, 12.5, 15, 10000000000]
                                }

def get_reverse_action_dict():
    '''Get dictionary that takes action index and returns indices of bins for 3 settings'''
    indices_lists = [[i for i in range(len(ACTION_DICT[action]))] for action in ACTION_DICT]
    possibilities = list(itertools.product(*indices_lists))
    possibility_dict = {}

    for i, possibility in enumerate(possibilities):
        possibility_dict[i] = possibility
	
    return possibility_dict

class Estimator():
    def __init__(self, label, data):
        self.label = label
        self.data = {"train" : data[0], "test" : data[1], "val" : data[2]}
        assert(len(self.data["train"].episodes) > len(self.data["test"].episodes))

class ModelEstimator(Estimator):
    def __init__(self, label, agent, data, policy, fqe_policy,conformal_predictor):
        super().__init__(label, data)
        self.agent = agent
        self.policy = policy
        self.fqe_policy = fqe_policy
        self.conformal_predictor = conformal_predictor


    def get_init_value_estimation(self, data):
        init_states = np.array([episode.observations[0] for episode in data.episodes])
        init_states = torch.FloatTensor(init_states).to(self.policy.device)

        return self.fqe_policy.get_q_values(init_states).gather(1, self.fqe_policy.get_actions(init_states,self.conformal_predictor)).squeeze().detach().cpu().numpy()

    def get_action_count(self):
        return Counter(self.data["test"].actions)
    
    def get_actions_within_one_bin(self):
        states=(torch.FloatTensor(self.data["test"].observations)).to(self.policy.device)
        actions = self.policy.get_actions(states,self.conformal_predictor).detach().cpu().numpy().flatten()
        reverse_action_dict = get_reverse_action_dict()
        model_setting = {
            "PEEP": np.array([reverse_action_dict[action][0] for action in actions]),
            "FiO2": np.array([reverse_action_dict[action][1] for action in actions]),
            'Adjusted Tidal Volume': np.array([reverse_action_dict[action][2] for action in actions])
        }

        phys_setting = {
            "PEEP" :np.array([reverse_action_dict[action[0]][0] for action in self.data["test"].actions]),
            "FiO2" :np.array([reverse_action_dict[action[0]][1] for action in self.data["test"].actions]),
            'Adjusted Tidal Volume' :np.array([reverse_action_dict[action[0]][2] for action in self.data["test"].actions])
        }
        num_close = {}
        key_list = list(model_setting.keys())

        for setting in key_list:
            num_close[setting] = 0
            for i in range(len(model_setting["PEEP"])):
                model_ind = model_setting[setting][i]
                phys_ind = phys_setting[setting][i]
                if model_ind <= phys_ind + 1 and model_ind >= phys_ind - 1:
                    num_close[setting] += 1

            num_close[setting] /= len(phys_setting[setting])
        return num_close

class PhysicianEstimator(Estimator):
    def __init__(self, data):
        super().__init__("Physician", data)


    def get_init_value_estimation(self, data):
        values = []
        for episode in data.episodes:
            if episode.rewards[-1] == 1:
                values.append(0.99 ** (len(episode)))
            elif episode.rewards[-1] == -1:
                values.append(-(0.99 ** (len(episode))))

        return np.array(values)

class MaxEstimator(Estimator):
    def __init__(self, data):
        super().__init__("Max", data)

    def get_init_value_estimation(self, data):
        values = []
        for episode in data.episodes:
            values.append(0.99 ** (len(episode)))

        return np.array(values)


def get_final_estimator(agent, states, rewards, index_of_split, confidence_level=None):
    policy_model = load_policy(agent, type=states, run_id=index_of_split, device="cuda")
    fqe_policy = load_FQN(agent, index_of_split, type=states, confidence_level=confidence_level)
    train_data, test_data, val_data,cal_data = load_data(states, rewards, index_of_split=index_of_split,with_cal=True)
    conformal_predictor=None
    if agent =="ConformalDQN":
        cal_buffer = prepare_buffer(cal_data, buffer_size=1e6, batch_size=256, device="cuda")
        conformal_predictor = ConformalPredictor(policy_model, cal_buffer, confidence_level=confidence_level)
        conformal_predictor.calibrate()
    else:
        raise ValueError("Agent not supported")


    return ModelEstimator("", agent, [train_data, test_data, val_data], policy_model, fqe_policy,conformal_predictor)