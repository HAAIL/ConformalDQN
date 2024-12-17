import torch
import torch.nn as nn
import torch.nn.functional as F


class DDQN(nn.Module):
    def __init__(self, state_size, action_size, layer_size):
        super(DDQN, self).__init__()
        self.input_shape = state_size
        self.action_size = action_size
        self.head_1 = nn.Linear(self.input_shape, layer_size)
        self.ff_1 = nn.Linear(layer_size, layer_size)
        self.ff_2 = nn.Linear(layer_size, action_size)

    def forward(self, input):
        """

        """
        x = torch.relu(self.head_1(input))
        x = torch.relu(self.ff_1(x))
        out = self.ff_2(x)

        return out



class DDQNSF(nn.Module):
    def __init__(self, state_dim, num_actions, layer_size=256):
        super(DDQNSF, self).__init__()
        self.q1 = nn.Linear(state_dim, layer_size)
        self.q2 = nn.Linear(layer_size, layer_size)
        self.q3 = nn.Linear(layer_size, num_actions)

        self.i1 = nn.Linear(state_dim, layer_size)
        self.i2 = nn.Linear(layer_size, layer_size)
        self.i3 = nn.Linear(layer_size, num_actions)

    def forward(self, state):
        q = F.relu(self.q1(state))
        q = F.relu(self.q2(q))

        i = F.relu(self.i1(state))
        i = F.relu(self.i2(i))
        i = self.i3(i)
        return self.q3(q), F.log_softmax(i, dim=1), i


class BCN(nn.Module):
    def __init__(self, state_dim, num_actions, layer_size):
        super(BCN, self).__init__()

        self.i1 = nn.Linear(state_dim, layer_size)
        self.i2 = nn.Linear(layer_size, layer_size)
        self.i3 = nn.Linear(layer_size, num_actions)

    def forward(self, state):


        i = F.relu(self.i1(state))
        i = F.relu(self.i2(i))
        i = self.i3(i)
        return F.log_softmax(i, dim=1), i

