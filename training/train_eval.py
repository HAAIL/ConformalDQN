import copy
import numpy as np
import torch
import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from models.ConformalDQN import ConformalDQN
from models.FQN import FittedQNetwork
from models.conformal_Predictor import ConformalPredictor



def train_ConformalDQN(replay_buffer, num_actions, state_dim, device, data_dic, parameters):
    # Initialize and load policy
    policy = ConformalDQN(
        num_actions,
        state_dim,
        device,
        parameters["discount"],
        parameters["optimizer"],
        parameters["optimizer_parameters"],
        parameters["polyak_target_update"],
        parameters["target_update_freq"],
        parameters["tau"],
        parameters["initial_eps"],
        parameters["end_eps"],
        parameters["eps_decay"],
        parameters["eval_eps"],
        parameters["layer_size"],

    )
    confidence_level = parameters["confidence_level"]

    print("confidence_level", confidence_level)
    conformal_predictor = ConformalPredictor(policy, data_dic["cal"], confidence_level=confidence_level)


    training_iters = 0

    best_state_dict = copy.deepcopy(policy.Q.state_dict())
    best_val_loss = np.inf

    while training_iters < parameters["max_timesteps"]:
        losses = []
        loss_terms = []
        all_losses = []
        for _ in range(int(parameters["eval_freq"])):
            loss, batch_loss_terms = policy.train(replay_buffer)
            losses.append(loss)
            loss_terms.append(batch_loss_terms)

        training_iters += int(parameters["eval_freq"])
        eval_loss = policy.evaluate(data_dic["val"])
        all_losses.append(np.mean(losses))
        print(
            f"Training iterations: {training_iters}   "
            f"train loss:{np.mean(losses)},  "
            f"loss_terms:{np.mean(loss_terms, 0)} "
            f" validation loss {eval_loss}")
        if eval_loss[0] < best_val_loss:
            best_val_loss = eval_loss[0]
            best_state_dict = copy.deepcopy(policy.Q.state_dict())



    policy.save(best_state_dict,parameters["results_dir"] + "ConformalDQN")
    print(f"policy saved at {parameters['results_dir']}ConformalDQN")
    # save conformal threshold as numpy
    conformal_predictor.calibrate()
    np.save(parameters["results_dir"] + "threshold", conformal_predictor.threshold)
    np.save(parameters["results_dir"] + "confidence_level", confidence_level)

    eval_buffer = data_dic["val"]
    if parameters["train_fqn"]:
        fqn = train_FQN(policy, replay_buffer, eval_buffer, state_dim, num_actions, device,
                        conformal_predictor=conformal_predictor)

        fqn.save(parameters["results_dir"] + "FQE")



def train_FQN(policy, reply_buffer, eval_buffer, state_dim, num_actions, device, conformal_predictor=None):
    FQN = FittedQNetwork(state_dim=state_dim, num_actions=num_actions, device=device,
                         conformal_predictor=conformal_predictor)
    losses = []
    best_eval_loss = np.inf
    for val_t in range(2000000):
        loss = FQN.train(reply_buffer, policy)
        losses.append(loss)
        if val_t % 5000 == 0:
            eval_loss = FQN.eval(eval_buffer, policy)[0]
            print(f"t{val_t}   FQN loss:", np.mean(losses), "     eval_loss:", eval_loss)
            losses = []
            if eval_loss < best_eval_loss:
                best_eval_loss = eval_loss
                best_q_model = copy.deepcopy(FQN.Q)
    FQN.Q = best_q_model
    return FQN




