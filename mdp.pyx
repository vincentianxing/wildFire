# Vincent Zhu
import csv
import sys
import time
import numpy as np
from cpython cimport array
import array

cdef class MDP:
    cdef public float gamma, epsilon
    cdef public list states, V, Q, actions
    cdef public list fire_location

    def __cinit__(self, gamma, epsilon):
        self.gamma = gamma
        self.epsilon = epsilon
        self.states = []
        self.fire_location = [(0, 0), (1, 1), (2, 0), (2, 2)]
        self.Q = [0] * 2304
        self.V = [0] * 2304
        self.actions = [-1] * 2304

    cpdef import_csv(self, filename):
        # input csv
        with open(filename, newline='') as csvfile:
            reader = csv.DictReader(csvfile)
            for row in reader:
                next_input_state = [int(row['State']),
                                    int(row['X']),
                                    int(row['Y']),
                                    int(row['F0']),
                                    int(row['F1']),
                                    int(row['F2']),
                                    int(row['F3'])]
                self.states.append(next_input_state)

    cdef float transition(self, list s_curr, int a, list s_next) except *:
        # T(s_curr, a, s_next) = P(s_next | s_curr, a)

        # s_curr and s_next are states {x, y, f0, f1, f2, f3}
        # a is action to take

        cdef float p = 0.0  # probability returned

        # movement changes; edge case stays the same
        if (a == 1) and (s_curr[2] - s_next[2] == 1) and (s_curr[1] == s_next[1]):  # up
            p = 1.0
        elif (a == 1) and (s_curr[2] == 0) and (s_curr[2] - s_next[2] == 0) and (
                s_curr[1] == s_next[1]):  # up edge
            p = 1.0
        if (a == 2) and (s_curr[2] - s_next[2] == -1) and (s_curr[1] == s_next[1]):  # down
            p = 1.0
        elif (a == 2) and (s_curr[2] == 2) and (s_curr[2] - s_next[2] == 0) and (
                s_curr[1] == s_next[1]):  # down edge
            p = 1.0
        if (a == 3) and (s_curr[1] - s_next[1] == 1) and (s_curr[2] == s_next[2]):  # left
            p = 1.0
        elif (a == 3) and (s_curr[1] == 0) and (s_curr[1] - s_next[1] == 0) and (
                s_curr[2] == s_next[2]):  # left edge
            p = 1.0
        if (a == 4) and (s_curr[1] - s_next[1] == -1) and (s_curr[2] == s_next[2]):  # right
            p = 1.0
        elif (a == 4) and (s_curr[1] == 2) and (s_curr[1] - s_next[1] == 0) and (
                s_curr[2] == s_next[2]):  # right edge
            p = 1.0

        # fire intensity changes, extinguish action (0)
        cdef tuple curr_location = (s_curr[1], s_curr[2])
        cdef int fire = 7

        if (a == 0) and (s_curr[1] != s_next[1]):
            p = 0.0
        elif (a == 0) and (s_curr[2] != s_next[2]):
            p = 0.0
        elif (a == 0) and (curr_location in self.fire_location):  # extinguish
            if curr_location == self.fire_location[0]:
                fire = 3
            elif curr_location == self.fire_location[1]:
                fire = 4
            elif curr_location == self.fire_location[2]:
                fire = 5
            elif curr_location == self.fire_location[3]:
                fire = 6

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
        elif (a == 0) and (curr_location not in self.fire_location):
            p = 1.0

        # other fire intensity changes
        for f in range(3, 7):
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

    cdef int get_reward(self, list s, int a):
        cdef int r = 0
        cdef int e = 0
        cdef int nofire = 0
        cdef int burnedout = 0
        cdef tuple curr_location = (s[1], s[2])
        cdef int fire = 7

        # E
        if a == 1 or a == 2 or a == 3 or a == 4:
            e = 0
        elif (a == 0) and (curr_location in self.fire_location):
            # which fire
            if curr_location == self.fire_location[0]:
                fire = 3
            elif curr_location == self.fire_location[1]:
                fire = 4
            elif curr_location == self.fire_location[2]:
                fire = 5
            elif curr_location == self.fire_location[3]:
                fire = 6
            # check if fire with intensity 1 or 2
            if s[fire] == 1 or s[fire] == 2:
                e = 5
            # intensity is not 1 or 2
            else:
                e = -10
        else:
            e = -10

        # get fire status
        for f in range(3, 7):
            if s[f] == 0:
                nofire += 1
            if s[f] == 3:
                burnedout += 1

        # reward
        r = (10 * nofire) - (10 * burnedout) + e
        return r

    cdef list get_possible_states(self, list s, int a):
        cdef list possible_states = []
        for i in self.states:
            if (i[1] == s[1]) and (i[2] == s[2]):
                possible_states.append(i)
            if a == 1:  # up
                if (i[1] == s[1]) and (i[2] == s[2] - 1):
                    possible_states.append(i)
            elif a == 2:  # down
                if (i[1] == s[1]) and (i[2] == s[2] + 1):
                    possible_states.append(i)
            elif a == 3:  # left
                if (i[1] == s[1] - 1) and (i[2] == s[2]):
                    possible_states.append(i)
            elif a == 4:  # right
                if (i[1] == s[1] + 1) and (i[2] == s[2]):
                    possible_states.append(i)
        return possible_states

    cdef list construct_t(self):
        cdef list curr = [0] * 2304
        cdef list action = [0] * 5
        cdef list next = [0] * 2304
        for s_curr in self.states:
            action = [0] * 5
            for a in range(5):
                curr[s_curr[0]] = action
                next = [0] * 2304
                for s_next in self.get_possible_states(s_curr, a):
                    action[a] = next
                    t = self.transition(s_curr, a, s_next)
                    next[s_next[0]] = t
        return curr

    cdef float construct_q(self, list s_curr, int a, list possible_states, list vv, list t_table):
        cdef float u = 0.0  # uncertain future utility
        cdef float t = 0.0
        cdef float v_next = 0.0
        cdef int r = 0
        cdef float q = 0.0
        for s_next in possible_states:
            t = t_table[s_curr[0]][a][s_next[0]]
            v_next = vv[s_next[0]]
            u += t * v_next
        r = self.get_reward(s_curr, a)
        q = r + (self.gamma * u)
        self.Q[s_curr[0]] = q
        return q

    cpdef tuple value_iteration(self):
        cdef double start = time.time()
        cdef double end
        cdef float converge = float('inf')
        cdef list t_table = self.construct_t()
        cdef list vv
        cdef float max_q
        cdef list possible_states
        cdef float q

        # check if converge
        while converge > self.epsilon:
            converge = 0.0
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
                        self.actions[s_curr[0]] = a
                # update V = max{Q(s_curr, a)}
                self.V[s_curr[0]] = max_q
                # calculate max change of V
                converge = max(converge, abs(vv[s_curr[0]] - self.V[s_curr[0]]))

            end = time.time()
            print(converge, end - start)

        return self.V, self.actions

# main
gamma = float(sys.argv[1])
epsilon = float(sys.argv[2])
wild_fire = MDP(gamma, epsilon)
wild_fire.import_csv('states.csv')

v, a = wild_fire.value_iteration()
# print(v)

with open('output.csv', 'w', newline='') as csvfile:
    fieldnames = ['index', 'action']
    writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
    writer.writeheader()
    for i in range(len(a)):
        writer.writerow({'index': i, 'action': a[i]})
