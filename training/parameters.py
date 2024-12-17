default_parameters = {
    "seed": 42,
    "run_id": 0,

    # ENV PARAMETERS
    "num_actions": 343,
    "state_dim": 44,
    "reward_mode": "ood",
    "state_mode": "ood",

    # TRAINING PARAMETERS
    "max_timesteps": 3000000,  # Max time steps to run environment or train for
    "start_timesteps": 0,
    "eval_freq": 5000,
    "device": "cuda",
    "discount": 0.75,
    "optimizer": "Adam",
    "optimizer_parameters": {
        "lr": 1e-3
    },
    "polyak_target_update": False,
    "target_update_freq": 5000,
    "tau": 0.05,
    "initial_eps": 0,
    "end_eps": 0,
    "eps_decay": 0.999985,
    "eval_eps": 0,

    # MEMORY PARAMETERS
    "buffer_size": 2e5,
    "batch_size": 256,

    # BCQ PARAMETERS
    "BCQ_threshold": 0.3,
    "alpha": 0.1,

    # NETWORK PARAMETERS
    "layer_size": 256,

    "agent": "ConformalDQN",
    "train_fqn": True,

}


ConformalDQN_parameters = {
    "optimizer_parameters": {
        "lr": 1e-6,
        "weight_decay": 1e-4
    },
    'reward_mode': 'intermediate',
    'state_mode': 'raw',
    'confidence_level':0.85


}

CQL_parameters={
    "optimizer_parameters": {
        "lr": 1e-4
    },
    "alpha": 0.1,
    'reward_mode': 'intermediate',
    'state_mode': 'raw',

}

ConformalDQN_ood_parameters={
    "optimizer_parameters": {
        "lr": 1e-3
    },
    'reward_mode': 'ood',
    'state_mode': 'ood',
    'confidence_level':0.85
}


FQN_parameters = {}