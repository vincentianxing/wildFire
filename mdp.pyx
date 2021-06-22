# Vincent Zhu
import csv
import sys
import time

cdef class MDP:
    cdef public float gamma, epsilon
    cdef public list states, p_states, V, Q, actions
    cdef public dict fire_location

    def __cinit__(self, gamma, epsilon):
        self.gamma = gamma
        self.epsilon = epsilon
        self.states = []
        self.p_states = []
        self.fire_location = {'f0': (0, 0), 'f1': (1, 1), 'f2': (2, 0), 'f3': (2, 2)}
        self.Q = [0] * 2304
        self.V = [0] * 2304
        self.actions = [-1] * 2304

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
                # for get_possible_states
                next_input_p_state = {'x': int(row['X']),
                                    'y': int(row['Y']),
                                    'f0': int(row['F0']),
                                    'f1': int(row['F1']),
                                    'f2': int(row['F2']),
                                    'f3': int(row['F3'])}
                self.p_states.append(next_input_p_state)

    def transition(self, s_curr, a, s_next):
        # T(s_curr, a, s_next) = P(s_next | s_curr, a)

        # s_curr and s_next are states {x, y, f0, f1, f2, f3}
        # a is action to take

        p = 0.0  # probability returned

        # movement changes; edge case stays the same
        if (a == 1) and (s_curr['y'] - s_next['y'] == 1) and (s_curr['x'] == s_next['x']):  # up
            p = 1.0
        elif (a == 1) and (s_curr['y'] == 0) and (s_curr['y'] - s_next['y'] == 0) and (
                s_curr['x'] == s_next['x']):  # up edge
            p = 1.0
        if (a == 2) and (s_curr['y'] - s_next['y'] == -1) and (s_curr['x'] == s_next['x']):  # down
            p = 1.0
        elif (a == 2) and (s_curr['y'] == 2) and (s_curr['y'] - s_next['y'] == 0) and (
                s_curr['x'] == s_next['x']):  # down edge
            p = 1.0
        if (a == 3) and (s_curr['x'] - s_next['x'] == 1) and (s_curr['y'] == s_next['y']):  # left
            p = 1.0
        elif (a == 3) and (s_curr['x'] == 0) and (s_curr['x'] - s_next['x'] == 0) and (
                s_curr['y'] == s_next['y']):  # left edge
            p = 1.0
        if (a == 4) and (s_curr['x'] - s_next['x'] == -1) and (s_curr['y'] == s_next['y']):  # right
            p = 1.0
        elif (a == 4) and (s_curr['x'] == 2) and (s_curr['x'] - s_next['x'] == 0) and (
                s_curr['y'] == s_next['y']):  # right edge
            p = 1.0

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
                    p = 0.8
                # stays the same with 20%
                elif s_curr[fire] == s_next[fire]:
                    p = 0.2
                else:
                    p = 0.0

            # extinguish on non-active fire (0) / burned out fire (3)
            if (s_curr[fire] == 0) or (s_curr[fire] == 3):
                # intensity does not change
                if s_curr[fire] == s_next[fire]:
                    p = 1.0
                else:
                    p = 0.0
        elif (a == 0) and (curr_location not in self.fire_location.values()):
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

    def get_reward(self, s, a):
        # cdef int r, e, nofire, burnedout
        r = 0
        e = 0
        nofire = 0
        burnedout = 0
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
                nofire += 1
            if s[f] == 3:
                burnedout += 1

        # reward
        r = (10 * nofire) - (10 * burnedout) + e
        return r

    def get_possible_statess(self, s, a):
        possible_states = []
        for i in self.states:
            if (i['x'] == s['x']) and (i['y'] == s['y']):
                possible_states.append(i)
            if a == 1:  # up
                if (i['x'] == s['x']) and (i['y'] == s['y'] - 1):
                    possible_states.append(i)
            elif a == 2:  # down
                if (i['x'] == s['x']) and (i['y'] == s['y'] + 1):
                    possible_states.append(i)
            elif a == 3:  # left
                if (i['x'] == s['x'] - 1) and (i['y'] == s['y']):
                    possible_states.append(i)
            elif a == 4:  # right
                if (i['x'] == s['x'] + 1) and (i['y'] == s['y']):
                    possible_states.append(i)
        return possible_states

    def get_possible_states(self, s, a):
        possible_states = []
        if a == 0:
            x = s['x']
            y = s['y']
        elif a == 1 and s['y'] != 0: # up
            x = s['x']
            y = s['y'] - 1
        elif a == 2 and s['y'] != 2: # down
            x = s['x']
            y = s['y'] + 1
        elif a == 3 and s['x'] != 0: # left
            x = s['x'] - 1
            y = s['y']
        elif a == 4 and s['x'] != 2: # right
            x = s['x'] + 1
            y = s['y']
        else:
            x = s['x']
            y = s['y']

        for f0 in range(2):
            for f1 in range(2):
                for f2 in range(2):
                    for f3 in range(2):
                        id = self.p_states.index({'x': x, 'y': y, 'f0': f0, 'f1': f1, 'f2': f2, 'f3': f3})
                        possible_states.append({'state': id, 'x': x, 'y': y, 'f0': f0, 'f1': f1, 'f2': f2, 'f3': f3})
        return possible_states

    def construct_t(self):
        curr = {}
        for s_curr in self.states:
            action = {}
            for a in range(5):
                curr[s_curr['state']] = action
                next = {}
                for s_next in self.get_possible_states(s_curr, a):
                    action[a] = next
                    t = self.transition(s_curr, a, s_next)
                    next[s_next['state']] = t
        return curr

    def construct_q(self, s_curr, a, possible_states, vv, t_table):
        u = 0  # uncertain future utility
        for s_next in possible_states:
            t = t_table[s_curr['state']][a][s_next['state']]
            v_next = vv[s_next['state']]
            u += t * v_next
        r = self.get_reward(s_curr, a)
        q = r + (self.gamma * u)
        self.Q[s_curr['state']] = q
        return q

    def value_iteration(self):
        start = time.time()

        converge = float('inf')
        # check if converge
        t_table = self.construct_t()
        while converge > self.epsilon:
            converge = 0
            vv = self.V.copy()
            # Loop over every possible state s
            for s_curr in self.states:
                max_q = float('-inf')
                #  Loop over every possible action a
                for a in range(5):
                    # get the list of possible states from s with action a
                    possible_states = self.get_possible_states(s_curr, a)
                    # update Q(s_curr,a)
                    q = self.construct_q(s_curr, a, possible_states, vv, t_table)
                    if q > max_q:
                        max_q = q
                        self.actions[s_curr['state']] = a
                # update V = max{Q(s_curr, a)}
                self.V[s_curr['state']] = max_q
                # calculate max change of V
                converge = max(converge, abs(vv[s_curr['state']] - self.V[s_curr['state']]))

            print(converge, time.time() - start)

        return self.V, self.actions

# main
gamma = float(sys.argv[1])
epsilon = float(sys.argv[2])
wild_fire = MDP(gamma, epsilon)
wild_fire.import_csv('states.csv')

# s_curr = {'x': 2, 'y': 2, 'f0': 1, 'f1': 0, 'f2': 0, 'f3': 0}
# p = wild_fire.get_possible_states(s_curr, 1)
# for pp in p:
#     print(pp)
# for a in range(0, 5):
#     t = 0
#     for s in wild_fire.states:
#         p = wild_fire.transition(s_curr, a, s)
#         t += p
#         if p != 0:
#             print(a, s, p)
#     print(t)
#     t = 0
#
# s_curr = {'state': 320, 'x': 1, 'y': 0, 'f0': 1, 'f1': 0, 'f2': 0, 'f3': 0}
# s_next = {'state': 325, 'x': 1, 'y': 0, 'f0': 1, 'f1': 0, 'f2': 1, 'f3': 1}
# pp = wild_fire.transition(s_curr, 0, s_next)
# print (0, s_next, pp)

v, a = wild_fire.value_iteration()
for i in range(100):
    print(a[i])
print(v)

with open('output.csv', 'w', newline='') as csvfile:
    fieldnames = ['index', 'action']
    writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
    writer.writeheader()
    for i in range(len(a)):
        writer.writerow({'index': i, 'action': a[i]})

# ps = wild_fire.get_possible_states(s_curr, 1)
# r = wild_fire.get_reward(s_curr, 1)
# q = wild_fire.construct_q(s_curr, 1, ps)
# print(r)
# print(q)
# print(s_curr)
# for i in ps:
#     print(i)
