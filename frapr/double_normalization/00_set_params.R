rm(list = ls())

param_rm <- 1 # how many frames to additionally remove after bleach
param_frame <- 0.203 # frame length in seconds
param_pre <- 5 # how much pre-bleach time to average, in seconds
param_quality <- c(0, 0) # exclude events automatically based on a minimum bleach depth [1] and gap ratio [2]
param_exclude <- c() # manually exclude events
