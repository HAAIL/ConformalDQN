import argparse
import datetime
import os
import random

import numpy as np
import torch

import parameters as params
import train_eval
from parameters import default_parameters
from utils.buffer import get_buffers

training_methods = {
    "ConformalDQN": train_eval.train_ConformalDQN,
}

parameters_dic = {
    "ConformalDQN": params.ConformalDQN_parameters,
    "ConformalDQN_ood": params.ConformalDQN_ood_parameters,

}


def get_args(parameters):
    # Load parameters
    args = argparse.Namespace(**parameters)
    return args


def main(parameters):

    ood_option= "_ood" if parameters["state_mode"] == "ood" else ""
    parameters.update(parameters_dic[parameters["agent"]+ood_option])

    current_timestamp = datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
    save_id = current_timestamp
    parameters["save_id"] = save_id

    parameters["results_dir"] = "./results/" + parameters["agent"] + "/" +parameters["state_mode"]+"_"+parameters["reward_mode"]+ "/" + str(parameters["run_id"]) + "/"

    if not os.path.exists(parameters["results_dir"]):
        os.makedirs(parameters["results_dir"])


    state_dim = parameters["state_dim"]
    num_actions = parameters["num_actions"]

    # Set seeds
    torch.manual_seed(parameters["seed"])
    np.random.seed(parameters["seed"])
    random.seed(parameters["seed"])
    if torch.cuda.is_available():
        torch.cuda.manual_seed_all(parameters["seed"])  # For CUDA
    # Enforcing deterministic behavior in PyTorch
    torch.backends.cudnn.deterministic = True
    torch.backends.cudnn.benchmark = False

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

    agent = parameters["agent"]
    with_cal = (agent == "ConformalDQN")
    buffer_data_dic = get_buffers(device, with_cal,parameters["run_id"],parameters["state_mode"],parameters["reward_mode"],parameters["buffer_size"],parameters["batch_size"])

    print(f"--------------------{agent}------------------")
    print(parameters)
    print("--------------------------------------")

    # Train agent
    training_methods[agent](buffer_data_dic["train"], num_actions, state_dim, device, buffer_data_dic,
                                       parameters)







if __name__ == "__main__":


    parser = argparse.ArgumentParser()
    # parser.add_argument("--agent", type=str, default="ConformalDQN", help="Agent to train [ConformalDQN]")
    parser.add_argument("--confidence_level", type=float, default=0.85, help="Confidence level for ConformalDQN")
    parser.add_argument("--state_mode", type=str, default="raw", help="State mode [raw, ood]")
    parser.add_argument("--reward_mode", type=str, default="intermediate", help="Reward mode [intermediate, ood]")
    parser.add_argument("--run_id", type=int, default=1, help="data split index [0-4]")

    args = parser.parse_args()

    default_parameters["agent"] = "ConformalDQN"
    default_parameters["state_mode"] = args.state_mode
    default_parameters["reward_mode"] = args.reward_mode
    default_parameters["run_id"] = args.run_id
    main(default_parameters)
