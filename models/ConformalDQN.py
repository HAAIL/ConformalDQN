import copy
import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F
from models.networks import DDQNSF


class ConformalDQN(object):
    def __init__(
            self,
            num_actions,
            state_dim,
            device,
            discount=0.99,
            optimizer="Adam",
            optimizer_parameters={},
            polyak_target_update=False,
            target_update_frequency=8e3,
            tau=0.005,
            initial_eps=1,
            end_eps=0.01,
            eps_decay=.999985,
            eval_eps=0.001,
            layer_size=256,

    ):

        self.device = device

        # Determine network type
        self.Q = DDQNSF(state_dim, num_actions, layer_size).to(
            self.device)
        self.Q_target = copy.deepcopy(self.Q)
        self.Q_optimizer = getattr(torch.optim, optimizer)(self.Q.parameters(), **optimizer_parameters)
        # self.scheduler = torch.optim.lr_scheduler.StepLR(self.Q_optimizer, step_size=10000, gamma=0.99)

        self.discount = discount

        # Target update rule
        self.maybe_update_target = self.polyak_target_update if polyak_target_update else self.copy_target_update
        self.target_update_frequency = target_update_frequency
        self.tau = tau

        # Decay for eps
        self.initial_eps = initial_eps
        self.end_eps = end_eps
        self.eps_decay = eps_decay
        self.eps = initial_eps

        # Evaluation hyper-parameters
        self.state_shape = (-1, state_dim)
        self.eval_eps = eval_eps
        self.num_actions = num_actions

        # Number of training iterations
        self.iterations = 0

        self.chosen_actions_dqn = []
        self.chosen_actions_conformal = []
        self.conformal_threshold = None

    def select_action(self, state, eval=False, nonconformity_threshold=None, expert_action=None):
        self.eps = max(self.eps_decay * self.eps, self.end_eps)
        eps = self.eval_eps if eval else self.eps
        # Select action according to policy with probability (1-eps)
        # otherwise, select random action
        if np.random.random() > eps:
            with torch.no_grad():
                if not isinstance(state, torch.Tensor):
                    state = torch.FloatTensor(state).reshape(self.state_shape).to(self.device)
                q_values, action_log_probs, _ = self.Q(state)
                if nonconformity_threshold is None:
                    q_values, action_log_probs, _ = self.Q(state)
                    return int(q_values.argmax(1))
                else:
                    confident_actions = (action_log_probs.exp() > (1 - nonconformity_threshold)).float()
                    # Masking the non-confident actions
                    confident_q_values = confident_actions * q_values + (1 - confident_actions) * -1e8
                    if confident_actions.max() == 0:
                        # print("No confident action found")
                        choosed_action = int(q_values.argmax(1))
                    else:
                        choosed_action = int(confident_q_values.argmax(1))
                    return choosed_action
        else:
            return np.random.randint(self.num_actions)

    def get_actions(self, states, conformal_predictor=None):
        actions = []
        q_values, action_log_probs, _ = self.Q(states)
        if conformal_predictor is None:
            actions = q_values.argmax(1).unsqueeze(1)
        else:
            action_probs = action_log_probs.exp()
            confidence = action_probs > (1 - conformal_predictor.threshold)
            confidences = confidence.float()
            confident_q_values = confidences * q_values + (1 - confidences) * -1e8
            no_confident_action_idx = confidences.max(1)[0] == 0
            confident_q_values[no_confident_action_idx] = q_values[no_confident_action_idx]

            actions = confident_q_values.argmax(1).unsqueeze(1)

        return actions

    def get_q_values(self, states):

        with torch.no_grad():
            q_values, _, _ = self.Q(states)
            return q_values

    def train(self, replay_buffer):
        # Sample replay buffer
        state, action, reward, done, next_state = replay_buffer.sample()
        reward = reward.squeeze(1)
        # Compute the target Q value
        with torch.no_grad():
            not_done = 1 - done
            # Initialize with zeros
            target_Q = torch.zeros((state.shape[0], self.num_actions)).to(self.device)

            # next action based on Q Network
            next_actions=torch.zeros_like(action)
            q_values, _, _ = self.Q(next_state[not_done.bool()])
            next_actions[not_done.bool()] = q_values.argmax(1, keepdim=True)

            # target q values
            target_Q[not_done.bool()], _, _ = self.Q_target(next_state[not_done.bool()])
            # target_Q[not_done.bool()] = target_Q[not_done.bool()].gather(1, next_actions[not_done.bool()])
            q_target =target_Q.gather(1,next_actions).squeeze(1)
            target_Q = reward + self.discount *  q_target

        # Get current Q estimate
        current_Q, imt, i = self.Q(state)
        current_Q = current_Q.gather(1, action).squeeze(1)

        # Compute Q loss
        Q_loss = F.huber_loss(current_Q, target_Q)
        i_loss = F.nll_loss(imt, action.reshape(-1))

        loss =  Q_loss +  i_loss + 1e-2 * i.pow(2).mean()

        # Optimize the Q
        self.Q_optimizer.zero_grad()
        loss.backward()
        # print("Q_loss",Q_loss.item())
        self.Q_optimizer.step()
        # self.scheduler.step()

        # Update target network by polyak or full copy every X iterations.
        self.iterations += 1
        self.maybe_update_target()
        return loss.item(), (Q_loss.item(), i_loss.item())



    def evaluate(self,val_buffer):
        n_batches = val_buffer.get_batch_count(val_buffer.batch_size)
        batch_losses = []
        with torch.no_grad():
            for i in range(n_batches):
                state, action, reward, done, next_state = val_buffer.get_batch(i, val_buffer.batch_size)
                reward = reward.squeeze(1)
                not_done = 1 - done
                # Initialize with zeros
                target_Q = torch.zeros((state.shape[0], self.num_actions)).to(self.device)

                # next action based on Q Network
                next_actions = torch.zeros_like(action)
                q_values, _, _ = self.Q(next_state[not_done.bool()])
                next_actions[not_done.bool()] = q_values.argmax(1, keepdim=True)

                # target q values
                target_Q[not_done.bool()], _, _ = self.Q_target(next_state[not_done.bool()])
                # target_Q[not_done.bool()] = target_Q[not_done.bool()].gather(1, next_actions[not_done.bool()])
                q_target = target_Q.gather(1, next_actions).squeeze(1)
                target_Q = reward + self.discount * q_target

                current_Q, imt, i = self.Q(state)
                current_Q = current_Q.gather(1, action).squeeze(1)

                # Compute Q loss
                Q_loss = F.huber_loss(current_Q, target_Q, delta=1)
                i_loss = F.nll_loss(imt, action.reshape(-1))

                loss = Q_loss + i_loss + 1e-2 * i.pow(2).mean()

                batch_losses.append((loss.item(), Q_loss.item(), i_loss.item()))
        return np.mean(batch_losses, axis=0)



    def polyak_target_update(self):
        for param, target_param in zip(self.Q.parameters(), self.Q_target.parameters()):
            target_param.data.copy_(self.tau * param.data + (1 - self.tau) * target_param.data)

    def copy_target_update(self):
        if self.iterations % self.target_update_frequency == 0:
            self.Q_target.load_state_dict(self.Q.state_dict())

    def save(self, best_state_dict, filename):
        torch.save(best_state_dict, filename + "_Q")
        torch.save(self.Q_optimizer.state_dict(), filename + "_optimizer")

    def load(self, filename):
        self.Q.load_state_dict(torch.load(filename + "_Q"))
        self.Q_target = copy.deepcopy(self.Q)
        self.Q_optimizer.load_state_dict(torch.load(filename + "_optimizer"))
