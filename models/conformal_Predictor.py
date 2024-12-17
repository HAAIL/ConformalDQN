import numpy as np
import torch


class ConformalPredictor:
    def __init__(self, policy, buffer, confidence_level=0.85):
        self.policy = policy
        self.buffer = buffer
        self.batch_size = self.buffer.batch_size
        self.confidence_level = confidence_level
        self.alpha = 1 - confidence_level
        self.nonconformity_scores = []
        self.threshold = None
        self.n = len(self.buffer)

    def compute_nonconformity_scores(self):
        # Retrieve all experiences from the buffer in batches
        data_size = len(self.buffer)
        num_batches = (data_size + self.batch_size - 1) // self.batch_size
        nonconformity_scores = []

        for i in range(int(num_batches)):
            batch_states, batch_actions, _, _, _ = self.buffer.get_batch(i, self.batch_size)
            with torch.no_grad():
                _, action_log_probs, _ = self.policy.Q(batch_states)
                action_probs = action_log_probs.exp()
            # Compute nonconformity scores for the batch
            batch_scores = (1 - action_probs.gather(1, batch_actions).squeeze(1)).cpu().numpy()
            nonconformity_scores.extend(batch_scores)

        self.nonconformity_scores = np.array(nonconformity_scores)

    def calibrate(self):
        self.compute_nonconformity_scores()
        q_level = np.ceil((self.n + 1) * (1 - self.alpha)) / self.n
        # Calculate the threshold for the given confidence level
        self.threshold = np.quantile(self.nonconformity_scores, q_level, method="higher")
        return self.threshold

