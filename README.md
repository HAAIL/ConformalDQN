# Distribution-Free Uncertainty Quantification in Mechanical Ventilation Treatment: A Conformal Deep Q-Learning Framework

Official code for the paper: ``Distribution-Free Uncertainty Quantification in Mechanical Ventilation
Treatment: A Conformal Deep Q-Learning Framework``

This repository contains the code for the `ConformalDQN`, a novel method combining conformal prediction and deep Q-learning to optimize mechanical ventilation in ICUs.





<!-- TABLE OF CONTENTS -->
## Table of Contents

* [Abstract](#about-the-project)
* [Installation](#installation)
* [Processing Data](#processing-data)
* [Training policies](#training-policies)
* [Evaluating policies](#evaluation)


<!-- ABOUT THE PROJECT -->
>**Abstract:**<div style="text-align: justify"> Mechanical Ventilation (MV) is a critical life-support intervention in intensive care units (ICUs). However, optimal ventilator settings are challenging to determine because of the complexity of balancing patient-specific physiological needs with the risks of adverse outcomes that impact morbidity, mortality, and healthcare costs. This study introduces ConformalDQN, a novel distribution-free conformal deep Q-learning approach for optimizing mechanical ventilation in intensive care units. By integrating conformal prediction with deep reinforcement learning, our method provides reliable uncertainty quantification, addressing the challenges of Q-value overestimation and out-of-distribution actions in offline settings.
We trained and evaluated our model using ICU patient records from the MIMIC-IV database. ConformalDQN extends the Double DQN architecture with a conformal predictor and employs a composite loss function that balances Q-learning with well-calibrated probability estimation. This enables uncertainty-aware action selection, allowing the model to avoid potentially harmful actions in unfamiliar states and handle distribution shift by being more conservative in out-of-distribution scenarios.
Evaluation against baseline models, including physician policies, policy constraint methods, and behavior cloning, demonstrates that ConformalDQN consistently makes recommendations within clinically safe and relevant ranges, outperforming other methods by increasing the 90-day survival rate. Notably, our approach provides an interpretable measure of confidence in its decisions, crucial for clinical adoption and potential human-in-the-loop implementations.
 </div>

<!-- INSTALLATION -->
## Installation

1. Create and activate virtual environment  (Linux)

```sh
python -m venv env
source env/bin/activate
```

2. install the required libraries
```
pip install -r requirements.txt 
```
<!-- PREPROCESSING DATA -->
## Processing Data

1. Data Extraction (MIMIC IV)
2. Data Imputation
3. Compute Trajectories
4. Modify elements
5. Split the data and create OOD

<!-- The following folders are extra steps which can be taken to potentially improve the performance of the policy. They do not replace the files containing the raw states, actions and rewards but simply create extra files where the data has been processed even more.
* discretize_actions: Turns 3-tuple of actions into 1 single number for each action
* remove_intermediate reward: Removes intermediate reward -->

To run the data preprocessing: 
1. Obtain the raw data following the instructions in data_preprocessing/data_extraction folder. You will need to insert your path in the scripts.
2. within the parent directory, run data preprocessing 
```
python3 data_preprocessing/run.py
```


<!-- TRAINING POLICIES -->
## Training policies
1. set the parameters in `training/parameters.py` to the desired values.
2. Train the policy.
```
python3 training/main.py
```

Running the above scripts will generate ouputs in `training/results` folder. 

4. Then run `python3 training/fit_FQN.py` to get all FQE policies  for evaluation).

<!-- EVALUATING POLICIES -->
## Evaluation

Evaluation directory contains all code necessary to generate graphs and results. 
Requires having 5 runs of the final policies in ``results`` directory.
To run the evaluation scripts:
```
cd evaluation
python3 compare_policies.py
python3 grouped_action_bar_plot.py
python3 plot_mortality.py
python3 compare_ood_id.py
```

## Bibtex

```
@inproceedings{eghbali2025conformaldqn,
  title={Distribution-Free Uncertainty Quantification in Mechanical Ventilation Treatment: A Conformal Deep Q-Learning Framework},
  author={Eghbali, Niloufar and Alhanai, Tuka and Ghassemi, Mohammad M},
  booktitle={Proceedings of the AAAI Conference on Artificial Intelligence (AAAI)},
  year={2025}
}

```

# References
[DeepVent](https://github.com/FlemmingKondrup/DeepVent)
