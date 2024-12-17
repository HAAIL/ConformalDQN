import sys
import os
from pathlib import Path

sys.path.append(os.getcwd())
path = Path(os.getcwd())
sys.path.append(str(path.parent.absolute()))

# Output average initial value estimations for CQL, DeepVent- and physician (mean and variance over 5 runs)
# (Corresponds to Table 1 in DeepVent paper)
import numpy as np

from estimator import PhysicianEstimator, get_final_estimator
from utils.load_utils import load_data

print("Getting initial value estimations for DeepVent, DeepVent- and Physician")
N_RUNS = 5
# Initialize data dictionary with 2 lists for each model (1 for train 1 for test)
data_dict = {
    "CQL" : [[], [],[]],
    "Physician": [[], [],[]],
    "DQN": [[], [],[]],
}
cl_list = [0.65,0.7,0.75, 0.8, 0.85, 0.9,0.99]

for cl in cl_list:
    data_dict.update({"ConformalDQN"+str(cl): [[], [],[]]})


# Get initial value estimations for each model for each run using estimator clas
for i in range(0,N_RUNS):
    print(f"Processing run {i}")
    estimator = get_final_estimator("CQL", "raw", "intermediate", index_of_split=i)
    data_dict["CQL"][0].append(estimator.get_init_value_estimation(estimator.data["train"]).mean())
    data_dict["CQL"][1].append(estimator.get_init_value_estimation(estimator.data["test"]).mean())
    data_dict["CQL"][2].append(estimator.get_init_value_estimation(estimator.data["val"]).mean())


    estimator = get_final_estimator("DQN", "raw", "intermediate", index_of_split=i)
    data_dict["DQN"][0].append(estimator.get_init_value_estimation(estimator.data["train"]).mean())
    data_dict["DQN"][1].append(estimator.get_init_value_estimation(estimator.data["test"]).mean())
    data_dict["DQN"][2].append(estimator.get_init_value_estimation(estimator.data["val"]).mean())


    for cl in cl_list:

        estimator = get_final_estimator("ConformalDQN", "raw", "intermediate", index_of_split=i, confidence_level=cl)
        data_dict[f"ConformalDQN{cl}"][0].append(estimator.get_init_value_estimation(estimator.data["train"]).mean())
        data_dict[f"ConformalDQN{cl}"][1].append(estimator.get_init_value_estimation(estimator.data["test"]).mean())
        data_dict[f"ConformalDQN{cl}"][2].append(estimator.get_init_value_estimation(estimator.data["val"]).mean())


    train_data, test_data,val_data,_ = load_data("raw", "no_intermediate", index_of_split=i,with_cal=True)
    estimator = PhysicianEstimator([train_data, test_data, val_data])
    data_dict["Physician"][0].append(estimator.get_init_value_estimation(estimator.data["train"]).mean())
    data_dict["Physician"][1].append(estimator.get_init_value_estimation(estimator.data["test"]).mean())
    data_dict["Physician"][2].append(estimator.get_init_value_estimation(estimator.data["val"]).mean())

# Transform all results into numpy arrays
for key in data_dict:
    for i, _ in enumerate(data_dict[key]):
        data_dict[key][i] = np.array(data_dict[key][i])

# Print formatted results
for i, label in enumerate(data_dict.keys()):
    print(label)
    print("-------------------------")
    means = [value.mean() for value in data_dict[label]]
    var = [value.std()  for value in data_dict[label]]
    print(f"Train mean: {means[0]}, Train variance: {var[0]}")
    print(f"Test mean: {means[1]}, Test variance: {var[1]}")
    print(f"Val mean: {means[2]}, Test variance: {var[2]}")
    print("-------------------------")
