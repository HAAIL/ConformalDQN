# Generate out-of-distribution dataset corresponding to patients that have one feature in top or bottom 1% 
# of entire dataset
# importing
import sys
import os
from pathlib import Path

sys.path.append(os.getcwd())
path = Path(os.getcwd())
sys.path.append(str(path.parent.absolute()))
import pandas as pd
import numpy as np
import scipy.stats as st
import pickle
from state_space import STATE_SPACE

from utils.load_utils import load_data
from constants import DATA_FOLDER_PATH

# Get full dataset without split
mdpdataset = load_data("raw", "no_intermediate", no_split=True)



# All features in our state space
STATE_SPACE=np.load(os.path.join(DATA_FOLDER_PATH,"states" ,"state_space.npy"))

train_indices = []
test_indices = []
def split_non_binary(proportion, param_name, param_index):
    # Split episodes according to if initial state has parameter param_name in top or bottom x% (where x = proportion) of whole dataset

    threshhold = st.norm.ppf(1-proportion) # States are normalized according to standard normal distribution

    # Get indices of episodes corresponding to top x% (where x = proportion)
    for i, episode in enumerate(mdpdataset.episodes):
        if episode.observations[0][param_index] > threshhold:
            test_indices.append(i)
        else:
            train_indices.append(i)

    threshhold = st.norm.ppf(proportion)

    # Get indices of episodes corresponding to bottom % (where x = proportion)
    for i, episode in enumerate(mdpdataset.episodes):
        if episode.observations[0][param_index] > threshhold:
            train_indices.append(i)
        else:
            test_indices.append(i)

# Indices not to be considered because get imputed out 
FORBIDDEN_INDICES = []

for i in range(len(STATE_SPACE)):
    print("Splitting", STATE_SPACE[i])
    # First condition checks if this is a binary feature in which case we can't get top and bottom 1% because there are only 2 possible values
    feature_observations = []
    for ep in mdpdataset.episodes:
        feature_observations+=(ep.observations[:,i].tolist())
    if len(np.unique(feature_observations)) <= 2 or i in FORBIDDEN_INDICES:
        continue
    split_non_binary(0.0001, STATE_SPACE[i], i)
    
train_indices = np.unique(np.array(train_indices))
test_indices = np.unique(np.array(test_indices))

# set 20% of train data as calibration data
cal_indices = np.random.choice(train_indices, int(0.2 * len(train_indices)), replace=False)
train_indices = np.setdiff1d(train_indices, cal_indices)

val_indices = np.random.choice(cal_indices, int(0.5 * len(cal_indices)), replace=False)
cal_indices = np.setdiff1d(cal_indices, val_indices)

test_episodes = []
train_episodes = []
cal_episodes = []
val_episodes = []
for i, episode in enumerate(mdpdataset.episodes):
    if i in test_indices:
        test_episodes.append(episode)
    elif i in train_indices:
        train_episodes.append(episode)
    elif i in cal_indices:
        cal_episodes.append(episode)
    elif i in val_indices:
        val_episodes.append(episode)

print("OOD no. episodes:", len(test_episodes))
print("In distribution no. episodes:", len(train_episodes))
with open(f"{DATA_FOLDER_PATH}/ood_test.pkl", "wb") as fp:
    pickle.dump(test_episodes, fp)

with open(f"{DATA_FOLDER_PATH}/ood_train.pkl", "wb") as fp:
    pickle.dump(train_episodes, fp)

with open(f"{DATA_FOLDER_PATH}/ood_cal.pkl", "wb") as fp:
    pickle.dump(cal_episodes, fp)

with open(f"{DATA_FOLDER_PATH}/ood_val.pkl", "wb") as fp:
    pickle.dump(val_episodes, fp)