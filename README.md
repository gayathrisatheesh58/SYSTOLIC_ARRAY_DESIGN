# SYSTOLIC_ARRAY_DESIGN
Hey Guys , Here in this Repo i am sharign the design of a 4x4 systolic array. 
There are 4 modules used to create the systolic array
A processing element with dual-stage pipelined MAC operation
A matrix feeder that takes in the streaming values of activations and weights and converts them to the structure of systolic array
A systolic array computation module that instantiate the processing element 16(4x4) times
A top module to instantiate both array and feeder modules
