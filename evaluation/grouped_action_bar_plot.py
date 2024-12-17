import sys
import os
from pathlib import Path
from models.conformal_Predictor import ConformalPredictor

from utils.buffer import  prepare_buffer
import torch

sys.path.append(os.getcwd())
path = Path(os.getcwd())
sys.path.append(str(path.parent.absolute()))

from utils.load_agents import load_policy, load_FQN
import numpy as np
import matplotlib.pyplot as plt
import itertools
from utils.load_utils import load_data
#action dictionairy with all bins as right ends
ACTION_DICT                 = {
                                'PEEP' : [5, 7, 9, 11, 13, 15, 1000000000],
                                'FiO2' : [30, 35, 40, 45, 50, 55, 1000000000],
                                'Adjusted Tidal Volume' : [2.5, 5, 7.5, 10, 12.5, 15, 10000000000]
                                }
#the units of every action setting
X_AXIS_LABELS = ['cmH20','Percentage (%)','ml/Kg']


#build reverse mapping to get action settings chosen from discrete action indice
def get_reverse_action_dict():
	#build list of possibilities
	indices_lists = [[ACTION_DICT[action][i] for i in range(len(ACTION_DICT[action]))] for action in ACTION_DICT]
	possibilities = list(itertools.product(*indices_lists))
	possibility_dict = {}
		
	for i, possibility in enumerate(possibilities):
	
		  possibility_dict[i] = possibility
	
	
	return possibility_dict

#sort 2d array along only one column
def special_sort(ar):
	for i in range(len(ar[0])):
		for j in range(i+1,len(ar[0])):
			if j < i:
				temp1 = ar[0][i]
				temp2 = ar[1][i]
				ar[0][i] = ar[0][j]
				ar[1][i] = ar[1][j]
				ar[0][j] = temp1
				ar[1][j] = temp2
	return ar


def plot_grouped_actions(d, theme='seaborn-whitegrid'):
	'''
	d is a dictionairy containing a policy and its predictions
	'''
	rad = get_reverse_action_dict()
	
	#set plot themse
	with plt.style.context(theme):
		for i in d.keys():
			d[i] = d[i].tolist()
			for j in range(len(d[i])):
				d[i][j] = rad[d[i][j]]
			d[i] = np.array(d[i])

		plt.rcParams.update({'font.size': 14})  # Set font size to 4 pt

		#build a subplot axes for every action 
		fig, ax = plt.subplots(len(ACTION_DICT.keys()),figsize=(8, 9))

		#iterate through every settable ventilation parameter
		for a in range(len(list(ACTION_DICT.keys()))):

			#get name of setting parameter currently iterating on ans set subplot title
			# accordingly
			k = list(ACTION_DICT.keys())[a]
			ax[a].set_title(k)
			
			#get the counts of every unique setting chose
			stats = [np.unique(d[i][:,a],return_counts=True) for i in d.keys()]
			stats = [list(special_sort(i)) for i in stats]


			#these are the widths of the bars for the barplot
			width=0.15

			#x axis tick labels
			labels = ACTION_DICT[k]
			x = np.arange(len(list(ACTION_DICT[k])))

			#loop through policies and take counts of unique values into 2d array
			for i in range(len(stats)):
				for j in ACTION_DICT[k]:
					if j not in stats[i][0]:
						stats[i][0]= np.append(stats[i][0], j)
						stats[i][1] = np.append(stats[i][1],0)

			#make nice x-tick title
			labels[-1] = ">{}".format(labels[-2])
			for i in range(0,len(labels)-1):
				if i == 0:
					labels[i] = "{}-{}".format(labels[i] - (labels[i+1]-labels[i]), labels[i])
				else:
					labels[i] = "{}-{}".format(labels[i-1].split('-')[1], labels[i])
			if k == 'PEEP':
				labels[0] = "0-5"
			

			#for each policy
			for i in range(len(d.keys())):
				#get name of policy
				policy = list(d.keys())[i]
				#shift factor says where in relation to other policies to plot bar
				shift_factor = i- int(d.__len__()/2)

				#plot the stats of the polict
				ax[a].bar(x + shift_factor*width, stats[i][1],width,label=policy)

			ax[a].set_ylabel("Action Counts")
			ax[a].set_xlabel(X_AXIS_LABELS[a])
			ax[a].set_xticks(x,labels)
			if a==0:
				ax[a].legend()

	plt.tight_layout()
	colors = ["sandybrown", "steelblue", "darkseagreen", "darkolivegreen", "lightskyblue", "yellowgreen", "lightcoral",
			  "darkslateblue"]
	plt.savefig("action_distribution.png", dpi=300)
	plt.show()



print("Making action distribution plot")

POLICIES = {"CQL": [], "DQN" :[], "ConformalDQN": []}
data_list=[]
cal_data_list=[]
runs=5
for P in POLICIES.keys():
	for i in range(runs):
		_,data,_,cal = load_data(states='raw', rewards='intermediate' ,index_of_split=i,with_cal=True)
		data_list.append(data)
		cal_data_list.append(cal)
		POLICIES[P].append(load_policy(P, type='raw', run_id=i))

#simply repeat physician actions over from data set 
pred_phys = data_list[0].actions
for i in range(len(POLICIES['CQL'])-1):
	pred_phys = np.concatenate([pred_phys, data_list[i].actions])

PREDS = {}
for P in POLICIES.keys():
	for i in range(len(POLICIES[P])):
		print(f"Processing run {i} for {P}")
		conformal_predictor=None
		if P == "ConformalDQN":
			cl=0.85
			cal_buffer=prepare_buffer(cal_data_list[i],256,1e6,"cuda")
			ConformalDQN_policy = load_policy("ConformalDQN", type="raw", run_id=i)
			conformal_predictor = ConformalPredictor(ConformalDQN_policy, cal_buffer, confidence_level=cl)
			th = conformal_predictor.calibrate()

		predicted_actions = POLICIES[P][i].get_actions(torch.FloatTensor(data_list[i].observations).to("cuda"),conformal_predictor=conformal_predictor).detach().cpu().numpy()
		if P not in PREDS.keys():
			PREDS[P] = predicted_actions
		else:
			PREDS[P] = np.concatenate([PREDS[P],predicted_actions])
PREDS['physician'] = pred_phys.reshape(-1)
PREDS['DDQN']= PREDS['DQN'].reshape(-1)
PREDS.pop("DQN")
PREDS['ConformalDQN']= PREDS['ConformalDQN'].reshape(-1)
PREDS['CQL']= PREDS['CQL'].reshape(-1)
plot_grouped_actions(PREDS)
