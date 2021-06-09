# Vincent Zhu
import csv
import random

cdef class MDP:
    # cdef dict s # state
    # cdef int a # action
    # cdef dict t # transition
    # cdef int r # reward
    cdef int gamma, epsilon
    cdef list states, V, Q
    cdef dict fire_location
    # states = []


    def __cinit__(self, gamma, epsilon):
        self.gamma = gamma
        self.epsilon = epsilon
        self.states = []
        self.fire_location = {'f0':(0,0), 'f1':(1,1), 'f2':(2,0), 'f3':(2,2)}
        self.Q = []
        self.V = []

        # initialize V
        for i in range (0, 2304):
            self.V[i] = 0
            self.Q[i] = 0


    def import_csv(self, filename):
        # input csv
        with open(filename, newline='') as csvfile:
            reader = csv.DictReader(csvfile)
            for row in reader:
                next_input_state = {'state': row['State'],
                             'x': row['X'],
                             'y': row['Y'],
                             'f0': row['F0'],
                             'f1': row['F1'],
                             'f2': row['F2'],
                             'f3': row['F3']}
                self.states.append(next_input_state)

        # print states
        for state in self.states:
            print(state)


    def transit(self, s_curr, a):
        # current location coordinate
        curr_location = (s_curr['x'], s_curr['y'])
        fire = ''

        # movement changes
        if a == 1: # up
            s_curr['y'] -= 1
        elif a == 2: # down
            s_curr['y'] += 1
        elif a == 3: # left
            s_curr['x'] -= 1
        elif a == 4: # right
            s_curr['x'] += 1
        # edge stays the same

        # fire intensity changes
        elif (a == 0) and (curr_location in self.fire_location.values()) : # extinguish
            if curr_location == self.fire_location['f0']:
                fire = 'f0'
            elif curr_location == self.fire_location['f1']:
                fire = 'f1'
            elif curr_location == self.fire_location['f2']:
                fire = 'f2'
            elif curr_location == self.fire_location['f3']:
                fire = 'f3'

            # extinguish on active fire (1 or 2)
            if s_curr[fire] == 1 or s_curr[fire] == 2:
                p = random.random()
                if 0 <= p < 0.8: # decrease 80%
                    s_curr[fire] -= 1
                # else stays the same 20%

            # extinguish on non-active fire (0) / burned out fire (3)
            if s_curr[fire] == 0 or s_curr[fire] == 3:
                s_curr[fire] = s_curr[fire]

        # change other fires
        for f in ['f0', 'f1', 'f2', 'f3']:
            if f != fire:
                s_curr = self.fire_change(s_curr, f)

        return s_curr


    def fire_change(self, s, f): # only fire that are not engaged
        # non-active fire (0)
        if s[f] == 0:
            p = random.random()
            if 0 <= p < 0.05: # increase 5%
                s[f] += 1
        # burned out fire (3)
        if s[f] == 3:
            s[f] = 3
        # active fire (1 or 2)
        if s[f] == 1 or s[f] == 2:
            p = random.random()
            if 0 <= p < 0.1: # increase 10%
                s[f] += 1

        return s


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

    def value_iteration(self):
    # Initialize a table V of value zeroes

    # !!! check valid move, invalid get -100 reward

        # Loop over every possible state s
        for s in self.states:
            #  Loop over every possible action a
            for a in [0, 1, 2, 3, 4]:
                # Get a list of all the transition from s
                # expected_reward = sum of all possible r * probability
                # expected_value = lookup V[s'] for each possible s', multiplied by probability, sum
                # action_value = expected_reward + gamma * expected_value
                
            # Set V[s] to the best action_value
        # Repeat until largest change in V[s] is below threshold

# main
wildFire = MDP(0, 0)
wildFire.import_csv('states.csv')
# wildFire.value_iteration()

