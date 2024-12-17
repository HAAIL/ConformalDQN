from models.FQN import FittedQNetwork
from models.ConformalDQN import ConformalDQN

from training.parameters import default_parameters as parameters
from training.parameters import (ConformalDQN_parameters,
                                 ConformalDQN_ood_parameters)


def load_policy(agent, type, run_id, device="cuda"):
    if type == "ood":
        path = f"../results/ConformalDQN/ood_ood/{run_id}/ConformalDQN"
    else:
        path = f"../results/ConformalDQN/raw_intermediate/{run_id}/ConformalDQN"

    if type == "ood":
        parameters.update(ConformalDQN_ood_parameters)
    else:
        parameters.update(ConformalDQN_parameters)
    policy = ConformalDQN(
        parameters["num_actions"],
        parameters["state_dim"],
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
        parameters["layer_size"]
    )


    if path is not None:
        print("policy loaded from: ", path)
        policy.load(path)
    return policy


def load_FQN(agent, run_id, type, confidence_level=None):
    if type == "ood":
        path = f"results/FQN/ood_ood/{run_id}/ConformalDQN_FQN"
    else:
        path=f"../results/FQN/raw_no_intermediate/{run_id}/ConformalDQN_FQN"
    if agent == "ConformalDQN" and confidence_level is not None:
        path=path.replace("ConformalDQN", f"ConformalDQN({confidence_level})")
    policy = FittedQNetwork(parameters["state_dim"], parameters["num_actions"], hidden_size=256,
                            device=parameters["device"])
    if path is not None:
        print("policy loaded from: ", path)
        policy.load(path)
    return policy
