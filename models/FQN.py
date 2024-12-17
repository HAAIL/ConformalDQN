import copy
import numpy as np
import torch
import torch.optim as optim
from torch.nn import functional as F
from .networks import DDQN


class FittedQNetwork(object):
    def __init__(self, state_dim, num_actions, hidden_size=256, device="cuda", conformal_predictor=None):
        super(FittedQNetwork, self).__init__()
        self.device = device
        self.num_actions = num_actions
        self.Q = DDQN(state_dim, num_actions, hidden_size).to(self.device)
        self.Q_target = copy.deepcopy(self.Q)
        self.discount = 0.99
        self.optimizer = optim.Adam(self.Q.parameters(), lr=1e-6)
        self.conformal_predictor = conformal_predictor
        self.iterations = 0
        self.target_update_frequency = 100

    def train(self, reply_buffer, policy, ):
        self.Q.train()
        states, actions, rewards, dones, next_states = reply_buffer.sample()
        rewards = rewards.squeeze(1)

        next_state_q_values = torch.zeros((states.shape[0], self.num_actions)).to(self.device)  # Initialize with zeros
        next_actions = torch.zeros((states.shape[0], 1), dtype=torch.int64).to(self.device)
        not_done = 1 - dones
        if not_done.any():  # Check if there are any non-terminal states
            next_state_q_values[not_done.bool()] = self.Q_target(next_states[not_done.bool()])
            next_actions[not_done.bool()] = policy.get_actions(next_states[not_done.bool()], self.conformal_predictor)

        next_state_action_q_values = next_state_q_values.gather(1, next_actions).squeeze(1)
        target_q_values = rewards + self.discount * next_state_action_q_values * (1 - dones)

        q_values = self.Q(states)

        loss = F.huber_loss(q_values.gather(1, actions).squeeze(1), target_q_values)


        self.optimizer.zero_grad()
        loss.backward()
        self.optimizer.step()

        self.iterations += 1
        self.copy_target_update()
        return loss.item()

    def eval(self, val_buffer, policy):
        self.Q.eval()
        data_size = len(val_buffer)
        num_batches = (data_size + val_buffer.batch_size - 1) // val_buffer.batch_size

        losses = []
        for i in range(int(num_batches)):
            states, actions, rewards, dones, next_states = val_buffer.get_batch(i, val_buffer.batch_size)

            rewards = rewards.squeeze(1)

            next_state_q_values = torch.zeros((states.shape[0], self.num_actions)).to(
                self.device)  # Initialize with zeros
            next_actions = torch.zeros((states.shape[0], 1), dtype=torch.int64).to(self.device)
            not_done = 1 - dones
            if not_done.any():  # Check if there are any non-terminal states
                next_state_q_values[not_done.bool()] = self.Q_target(next_states[not_done.bool()])
                next_actions[not_done.bool()] = policy.get_actions(next_states[not_done.bool()],
                                                                   self.conformal_predictor)

            next_state_action_q_values = next_state_q_values.gather(1, next_actions).squeeze(1)
            target_q_values = rewards + self.discount * next_state_action_q_values * (1 - dones)

            q_values = self.Q(states)

            loss = F.huber_loss(q_values.gather(1, actions).squeeze(1), target_q_values, delta=1)
            losses.append(loss.item())

        return losses

    def get_q_values(self, states):
        with torch.no_grad():
            q_values = self.Q(states)
            return q_values

    def get_actions(self, states, conformal_predictor=None):
        actions = self.Q(states).argmax(1).unsqueeze(1)
        return actions

    def select_action(self, state, eval=False, nonconformity_threshold=None):
        with torch.no_grad():
            state = torch.FloatTensor(state).reshape(1, -1).to(self.device)
            q_values = self.Q(state)
            return int(q_values.argmax(1))

    def copy_target_update(self):
        if self.iterations % self.target_update_frequency == 0:
            self.Q_target.load_state_dict(self.Q.state_dict())

    def save(self, filename):
        torch.save(self.Q.state_dict(), filename + "_Q")

    def load(self, filename):
        self.Q.load_state_dict(torch.load(filename + "_Q"))
        self.Q_target = copy.deepcopy(self.Q)
