from models.FQN import FittedQNetwork
from models.conformal_Predictor import ConformalPredictor
from parameters import default_parameters
from utils.buffer import get_buffers
from utils.load_agents import load_policy
import argparse
import numpy as np
import copy
import os
import torch

parser = argparse.ArgumentParser()
parser.add_argument('--agent', default="ConformalDQN", type=str, choices=["DQN", "BCQ", "ConformalDQN", "CQL"])
args = parser.parse_args()


def fit_FQN(agent,confidence_level=None,continue_training=False,checkpoint_path=None):
    policy = load_policy(agent, default_parameters["state_mode"], default_parameters["run_id"],device=default_parameters["device"])
    data_dic = get_buffers(device=default_parameters["device"], with_cal=True, run_id=default_parameters["run_id"],
                           state_mode=default_parameters["state_mode"], reward_mode="no_intermediate",
                           buffer_size=1e6, batch_size=default_parameters["batch_size"])
    conformal_predictor = None
    if agent == "ConformalDQN":
        conformal_predictor = ConformalPredictor(policy, data_dic["cal"], confidence_level=confidence_level)
        conformal_predictor.calibrate()


    FQN = FittedQNetwork(default_parameters["state_dim"] ,default_parameters["num_actions"], hidden_size=256,
                         device=default_parameters["device"], conformal_predictor=conformal_predictor)
    if continue_training:
        FQN.load(checkpoint_path)

    losses = []
    best_eval_loss = np.inf
    for val_t in range(default_parameters["max_timesteps"]):
        loss = FQN.train(data_dic["train"], policy)
        losses.append(loss)
        if val_t % 100 == 0:
            eval_loss = FQN.eval(data_dic["val"], policy)
            print(f"t{val_t}   FQN loss:", np.mean(losses), "     eval_loss:", eval_loss)
            losses = []
            if eval_loss < best_eval_loss:
                best_eval_loss = eval_loss
                best_q_model = copy.deepcopy(FQN.Q)
    FQN.Q = best_q_model
    FQN.Q_target = copy.deepcopy(FQN.Q)
    return FQN


if __name__ == "__main__":

    resume_training=False

    agent="ConformalDQN"



    default_parameters["agent"] = agent
    default_parameters["state_mode"] = "raw"
    default_parameters["reward_mode"] = "no_intermediate"
    default_parameters["run_id"] = 0
    default_parameters["batch_size"] = 100
    default_parameters["max_timesteps"] = 2000 # 4000 for DQN, 8000 for BCQ, 4000 for ConformalDQN, 8000 for CQL


    # set seeds
    np.random.seed(default_parameters["seed"])
    torch.manual_seed(default_parameters["seed"])
    torch.cuda.manual_seed(default_parameters["seed"])
    torch.cuda.manual_seed_all(default_parameters["seed"])
    torch.backends.cudnn.deterministic = True
    torch.backends.cudnn.benchmark = False


    print(f"--------- FQN- {agent}----------")
    print(default_parameters)
    print("-------------------")

    for i in range(5):
        confidence_level=0.85
        default_parameters["run_id"]=i
        save_dir = "./results/FQN/" + default_parameters["state_mode"] + "_" + default_parameters[
            "reward_mode"] + "/" + str(default_parameters["run_id"]) + "/"
        if not os.path.exists(save_dir):
            os.makedirs(save_dir)
        default_parameters["run_id"] = i

        checkpoint_path = f"{save_dir}{agent}({confidence_level})_FQN" if agent=="ConformalDQN" else f"{save_dir}{agent}_FQN"

        FQN = fit_FQN(agent,confidence_level,continue_training=resume_training,checkpoint_path=checkpoint_path)

        if agent=="ConformalDQN":
            FQN.save(f"{save_dir}{agent}({confidence_level})_FQN")
            print("Fitted Q Network saved at:", f"{save_dir}{agent}({confidence_level})_FQN")
        else:
            FQN.save(f"{save_dir}{agent}_FQN")
            print("Fitted Q Network saved at:", f"{save_dir}{agent}_FQN")