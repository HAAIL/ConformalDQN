# importing
import sys
import os
from pathlib import Path

sys.path.append(os.getcwd())
path = Path(os.getcwd())
sys.path.append(str(path.parent.absolute()))

from d3rlpy.dataset import MDPDataset
from constants import DATA_FOLDER_PATH
from sklearn.model_selection import train_test_split
import numpy as np

VALIDATION_SPLIT = 0.2
states = np.load(f"{DATA_FOLDER_PATH}/states/raw_states.npy")
actions = np.load(f"{DATA_FOLDER_PATH}/actions/1Ddiscretized_actions.npy")
rewards = np.load(f"{DATA_FOLDER_PATH}/rewards/rewards_without_intermediate.npy")
terminals = np.load(f"{DATA_FOLDER_PATH}/done_flags/done_flags.npy")

data = MDPDataset(states, actions, rewards, terminals)
if (not os.path.isdir(f"{DATA_FOLDER_PATH}/indices")):
    os.mkdir(f"{DATA_FOLDER_PATH}/indices")

# Spliting the Training and Testing Data 
def split_data(index):
    indices = np.arange(len(data.episodes))
    train_data_indices, test_data_indices = train_test_split(indices, test_size=2*VALIDATION_SPLIT)
    test_data_indices, val_data_indices = train_test_split(test_data_indices, test_size=0.5)
    val_data_indices, cal_data_indices = train_test_split(val_data_indices, test_size=0.5)
    # print("Train data length:", len(train_data_indices))
    # print("Test data length:", len(test_data_indices))
    # print("Val data length:", len(val_data_indices))
    # print("Cal data length:", len(cal_data_indices))

    np.save(f"{DATA_FOLDER_PATH}/indices/train_indices_{index}.npy", train_data_indices)
    np.save(f"{DATA_FOLDER_PATH}/indices/test_indices_{index}.npy", test_data_indices)
    np.save(f"{DATA_FOLDER_PATH}/indices/val_indices_{index}.npy", val_data_indices)
    np.save(f"{DATA_FOLDER_PATH}/indices/cal_indices_{index}.npy", cal_data_indices)

for i in range(5):
    split_data(i)
