# Vincent Zhu
import csv
import random

cdef class MDP:
    cdef public int gamma, epsilon
    cdef public list states, V, Q
    cdef public dict fire_location

    # gamma, epsilon = 0, 0
    # states, V, Q = [], [], []
    # fire_location = {}

    def __cinit__(self, gamma, epsilon):
        self.gamma = gamma
        self.epsilon = epsilon
        self.states = []
        self.fire_location = {'f0': (0, 0), 'f1': (1, 1), 'f2': (2, 0), 'f3': (2, 2)}
        self.Q = []
        self.V = []

        # initialize V
        # for i in range(0, 2304):
        #     self.V[i] = 0
        #     self.Q[i] = 0

    def import_csv(self, filename):
        # input csv
        with open(filename, newline='') as csvfile:
            reader = csv.DictReader(csvfile)
            for row in reader:
                next_input_state = {'state': int(row['State']),
                                    'x': int(row['X']),
                                    'y': int(row['Y']),
                                    'f0': int(row['F0']),
                                    'f1': int(row['F1']),
                                    'f2': int(row['F2']),
                                    'f3': int(row['F3'])}
                self.states.append(next_input_state)

        # print states
        # for state in self.states:
        #     print(state)

    def transition(self, s_curr, a, s_next):
        # T(s_curr, a, s_next) = P(s_next | s_curr, a)

        # s_curr and s_next are states {x, y, f0, f1, f2, f3}
        # a is action to take

        p = 0.0  # probability returned

        # movement changes; edge case stays the same
        if (a == 1) and (s_curr['y'] - s_next['y'] == 1):  # up
            p = 1.0
        elif (a == 1) and (s_curr['y'] == 0) and (s_curr['y'] - s_next['y'] == 0):  # up edge
            p = 1
        if (a == 2) and (s_curr['y'] - s_next['y'] == -1):  # down
            p = 1.0
        elif (a == 2) and (s_curr['y'] == 2) and (s_curr['y'] - s_next['y'] == 0):  # down edge
            p = 1.0
        if (a == 3) and (s_curr['x'] - s_next['x'] == 1):  # left
            p = 1.0
        elif (a == 3) and (s_curr['x'] == 0) and (s_curr['x'] - s_next['x'] == 0):  # left edge
            p = 1.0
        if (a == 4) and (s_curr['x'] - s_next['x'] == -1):  # right
            p = 1.0
        elif (a == 4) and (s_curr['x'] == 0) and (s_curr['x'] - s_next['x'] == 0):  # right edge
            p = 1.0

        if (abs(s_curr['x'] - s_next['x']) > 1) or (abs(s_curr['y'] - s_next['y']) > 1):
            p = 0.0

        # fire intensity changes, extinguish action (0)
        curr_location = (s_curr['x'], s_curr['y'])
        fire = ''

        if (a == 0) and (s_curr['x'] != s_next['x']):
            p = 0.0
        elif (a == 0) and (s_curr['y'] != s_next['y']):
            p = 0.0
        elif (a == 0) and (curr_location in self.fire_location.values()):  # extinguish
            if curr_location == self.fire_location['f0']:
                fire = 'f0'
            elif curr_location == self.fire_location['f1']:
                fire = 'f1'
            elif curr_location == self.fire_location['f2']:
                fire = 'f2'
            elif curr_location == self.fire_location['f3']:
                fire = 'f3'

            # extinguish on active fire (1 or 2)
            if (s_curr[fire] == 1) or (s_curr[fire] == 2):
                # decrease by 1 with 80%
                if s_curr[fire] - s_next[fire] == 1:
                    p += 0.8
                # stays the same with 20%
                elif s_curr[fire] == s_next[fire]:
                    p += 0.2
                else:
                    p += 0.0

            # extinguish on non-active fire (0) / burned out fire (3)
            if (s_curr[fire] == 0) or (s_curr[fire] == 3):
                # intensity does not change
                if s_curr[fire] == s_next[fire]:
                    p += 1.0
                else:
                    p += 0.0

            if p == 0.0:
                p = 1.0

        # other fire intensity changes
        for f in ['f0', 'f1', 'f2', 'f3']:
            if f != fire:
                # non-active fire (0)
                if s_curr[f] == 0:
                    # increase by 1 with 5%
                    if s_next[f] - s_curr[f] == 1:
                        p = p * 0.05
                    # stays the same at 0 with 0.95%
                    elif s_next[f] == s_curr[f]:
                        p = p * 0.95
                    else:
                        p = 0.0
                # burned out fire (3)
                if s_curr[f] == 3:
                    # stays burned out at 3
                    if s_next[f] == 3:
                        p = p * 1.0
                    else:
                        p = 0.0
                # active fire (1 or 2)
                if (s_curr[f] == 1) or (s_curr[f] == 2):
                    # increase by 1 with 10%
                    if s_next[f] - s_curr[f] == 1:
                        p = p * 0.1
                    # stays the same at 1 or 2 with 90%
                    elif s_next[f] == s_curr[f]:
                        p = p * 0.9
                    else:
                        p = 0.0

        return p

    # def fire_change(self, s, f):  # only fire that are not engaged
    #     # non-active fire (0)
    #     if s[f] == 0:
    #         p = random.random()
    #         if 0 <= p < 0.05:  # increase 5%
    #             s[f] += 1
    #     # burned out fire (3)
    #     if s[f] == 3:
    #         s[f] = 3
    #     # active fire (1 or 2)
    #     if s[f] == 1 or s[f] == 2:
    #         p = random.random()
    #         if 0 <= p < 0.1:  # increase 10%
    #             s[f] += 1
    #
    #     return s

    def get_reward(self, s, a):
        cdef int r, e, noFire, burnedOut
        curr_location = (s['x'], s['y'])

        # E
        if a == 1 or a == 2 or a == 3 or a == 4:
            e = 0
        elif (a == 0) and (curr_location in self.fire_location.values()):
            # which fire
            if curr_location == self.fire_location['f0']:
                fire = 'f0'
            elif curr_location == self.fire_location['f1']:
                fire = 'f1'
            elif curr_location == self.fire_location['f2']:
                fire = 'f2'
            elif curr_location == self.fire_location['f3']:
                fire = 'f3'
            # check if fire with intensity 1 or 2
            if s[fire] == 1 or s[fire] == 2:
                e = 5
            # intensity is not 1 or 2
            else:
                e = -10
        else:
            e = -10

        # get fire status
        for f in ['f0', 'f1', 'f2', 'f3']:
            if s[f] == 0:
                noFire += 1
            if s[f] == 3:
                burnedOut += 1

        # reward
        r = 10 * noFire - 10 * burnedOut + e
        return r

    # def value_iteration(self):
    #     # Initialize a table V of value zeroes
    #
    #     # !!! check valid move, invalid get -100 reward
    #
    #     # Loop over every possible state s
    #     for s in self.states:
    #         #  Loop over every possible action a
    #         for a in [0, 1, 2, 3, 4]:
    #     # Get a list of all the transition from s
    #     # expected_reward = sum of all possible r * probability
    #     # expected_value = lookup V[s'] for each possible s', multiplied by probability, sum
    #     # action_value = expected_reward + gamma * expected_value
    #
    #     # Set V[s] to the best action_value
    #     # Repeat until largest change in V[s] is below threshold

# main

wild_fire = MDP(0, 0)
wild_fire.import_csv('states.csv')
s_curr = {'x': 0, 'y': 0, 'f0': 0, 'f1': 0, 'f2': 0, 'f3': 0}
for a in range(0, 5):
    t = 0
    for s in wild_fire.states:
        p = wild_fire.transition(s_curr, a, s)
        t += p
        if p != 0:
            print(a, s, p)
    print(t)
    t = 0

s_next = {'state': 1877, 'x': 1, 'y': 2, 'f0': 1, 'f1': 1, 'f2': 1, 'f3': 1}
pp = wild_fire.transition(s_curr, 4, s_next)
print (4, s_next, pp)
