# Make Out of Distribution vs. In Distribution value estimation plot for ConformalDQN and DDQN (Figure 4 in ConformalDQN/DeepVent paper)

# importing
import sys
import os
from pathlib import Path

sys.path.append(os.getcwd())
path = Path(os.getcwd())
sys.path.append(str(path.parent.absolute()))

import numpy as np
import matplotlib.pyplot as plt


from estimator import get_final_estimator
from utils.load_utils import load_data
print("Making OOD vs ID comparison plot")
N_RUNS = 5 # Number of runs in experiment that we are graphing for

# Initialize data dictionary with 2 lists for each model (1 for OOD, 1 for in distribution)
data_dict = {
    "CQL" : [[], []],
    "DQN" : [[], []],
    "ConformalDQN": [[], []],
}
cl=0.85

for i in range(N_RUNS):
    print(f"Processing run {i}")
    # For DDQN and CQL, for each run, get mean of initial value estimations for out of distribution and in distribution using estimator class
    estimator = get_final_estimator("CQL", "ood", "ood", index_of_split=i)
    data_dict["CQL"][0].append(estimator.get_init_value_estimation(estimator.data["validate"]).mean())
    data_dict["CQL"][1].append(estimator.get_init_value_estimation(estimator.data["test"]).mean())


    estimator = get_final_estimator("DQN", "ood", "ood", index_of_split=i)
    data_dict["DQN"][0].append(estimator.get_init_value_estimation(estimator.data["validate"]).mean())
    data_dict["DQN"][1].append(estimator.get_init_value_estimation(estimator.data["test"]).mean())

    estimator = get_final_estimator("ConformalDQN", "ood", "ood", index_of_split=i, confidence_level=cl)
    data_dict["ConformalDQN"][0].append(estimator.get_init_value_estimation(estimator.data["validate"]).mean())
    data_dict["ConformalDQN"][1].append(estimator.get_init_value_estimation(estimator.data["test"]).mean())

# Transform list of means (one for each run) into numpy array to make it easier to take mean and variance
for key in data_dict:
    for i, _ in enumerate(data_dict[key]):
        data_dict[key][i] = np.array(data_dict[key][i])


    # Set parameters for graphs
    plt.rcParams.update({'font.size': 14})
    fig, ax = plt.subplots()
    x = np.array([0, 0.4])  # x positions for "In Distribution" and "Out of Distribution"
    width = 0.05
    colors = ["sandybrown","steelblue","darkseagreen","darkolivegreen","lightskyblue", "yellowgreen","lightcoral", "darkslateblue"]

    # For each model in data_dict, plot mean and variance over all runs
    for i, (label, values) in enumerate(data_dict.items()):
        means = [np.mean(value) for value in values]
        var = [np.var(value) for value in values]
        offset = (i - len(data_dict) / 2) * width

        ax.bar(x + offset, means, yerr=var, width=width, align='center', label=label, color=colors[i])

    # Set title, label, legend, etc. for plot
    ax.axhline(y=1, color='r', linestyle='--', label="Overestimation Threshold")
    ax.legend(loc="upper left")
    ax.set_xticks(x)
    ax.set_xticklabels(["In Distribution", "Out of Distribution"])
    ax.set_title(f"Mean Initial Q Values OOD vs ID")
    ax.set_ylabel("Mean Initial Q Value")
    plt.savefig("ood_plot1.png", dpi=300)

    plt.show()
