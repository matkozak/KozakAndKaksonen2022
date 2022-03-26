######################
### Load libraries ###
######################

library(tidyverse)

# define the pre-bleach window to normalize to
# should be a single numeric value representing time in seconds
if (exists("param_pre") == 0) {
  stop("Please define param_pre before running the code.")
}

# param_pre <- 10

#############################
### Normalize intensities ###
#############################

calc_frap <- function(df, pre = 20, frame = 0.5){
  # calc_frap function re-written to only normalize GFP to pre-bleach level
  # no imaging bleach or bg correction due to TIRF mode
  # normalizes RFP signal to 0-1 only to make plotting both on one plot possible
  # should it also normalize post-bleach GFP to 0? right now it does NOT
  bleach <- df$bleach_frame[1]
  
  gfp <- df %>%
    filter(channel == 'GFP')
  
  rfp <- df %>%
    filter(channel == 'RFP')
  
  gfp_pre <- gfp %>%
    filter(between(time, -pre, -frame)) %>%
    .$intensity %>%
    mean(na.rm = T)
  
  gfp_zero_n <- gfp %>%
    filter(time == 0) %>%
    pull(intensity) %>%
    `/`(gfp_pre)
  
  rfp_min <- rfp %>%
    .$intensity %>%
    min(na.rm = T)
  
  rfp_max <- rfp %>%
    .$intensity %>%
    max(na.rm = T)
   
  a <- bind_rows(
    gfp %>%
      mutate(normalized = intensity/gfp_pre,
             norm_full = (normalized - gfp_zero_n)/(1 - gfp_zero_n)),
    rfp %>%
      mutate(normalized = (intensity - rfp_min)/(rfp_max - rfp_min))
  )
  return(a)
}

bd <- function(df, pre, frame){
  # function to calculate bleach depth
  # how much of initial patch fluorescence was lost in the bleaching
  pre_mean <- df %>%
    filter(channel == 'GFP' & between(time, -pre, -frame)) %>%
    pull(intensity) %>%
    mean(na.rm = T)
  
  post <- df %>%
    filter(channel == 'GFP' & time == 0) %>%
    pull(intensity)
  
  df <- df %>%
    mutate(bleach_depth = (pre_mean - post)/pre_mean)
  
  return(df)
}

# apply calc_frap to all patches
all_patches <- all_patches %>% 
  map(calc_frap, pre = param_pre, frame = param_frame) %>%
  map(bd, pre = param_pre, frame = param_frame)
  
#################################
### Select and average events ###
#################################

# filter dataframe list by selected patch ids
selected_patches <- all_patches[param_select]
selected_patches <- bind_rows(selected_patches, .id = "id") %>%
  fill(1:ncol(.))

# average events (GFP channel only)
selected_patches_mean <- selected_patches %>%
  filter(channel == "GFP") %>%
  filter(between(time, -10, 150)) %>% # fit script has its own limit setting but reduced size is good anyway
  group_by(time) %>%
  summarise(recovery = mean(norm_full),
            sd = sd(normalized),
            se = sd/sqrt(length(norm_full)),
            from = 'experiment')