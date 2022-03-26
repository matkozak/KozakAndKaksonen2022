######################
### Load libraries ###
######################

# define the pre-bleach window to normalize to
# should be a single numeric value representing time in seconds
# param_pre <- 5

if (exists("param_pre") == 0) {
  stop("Please define param_pre before running the code.")
}

########################
### Define functions ###
########################

calc_frap <- function(df, pre, frame){
  # calc_frap function re-written to only normalize GFP to pre-bleach level
  # no imaging bleach or bg correction due to TIRF mode
  # normalizes RFP signal to 0-1 only to make plotting both on one plot possible
  # should it also normalize post-bleach to 0? right now it does NOT
  df <- df %>%
    mutate(patch_corr = patch - background, cell_corr = cell - background)
  
  pre_mean <- df %>%
    filter(between(time, -pre, -frame)) %>%
    summarise(patch = mean(patch_corr, na.rm = T),
              cell = mean(cell_corr, na.rm = T))
  
  df <- df %>%
    mutate(norm_double = (patch_corr/pre_mean$patch)/(cell_corr/pre_mean$cell))
           
  zero_norm <- df %>%
    filter(time == 0) %>%
    pull(norm_double)
  
  df <- df %>%
    mutate(norm_full = (norm_double - zero_norm)/(1 - zero_norm))
  
  return(df)
}

bd <- function(df, pre, frame){
  # function to calculate bleach depth
  # how much of initial patch fluorescence was lost in the bleaching
  pre_mean <- df %>%
    filter(between(time, -pre, -frame)) %>%
    pull(patch_corr) %>%
    mean(na.rm = T)
    
  post <- df %>%
    filter(time == 0) %>%
    pull(patch_corr)
    
  df <- df %>%
    mutate(bleach_depth = (pre_mean - post)/pre_mean)
  
  return(df)
}

gr <- function(df, pre, frame){
  # function to calculate gap ratio
  # how much of initial cell fluorescence remains after bleaching
  pre_mean <- df %>%
    filter(between(time, -pre, -frame)) %>%
    pull(cell_corr) %>%
    mean(na.rm = T)
  
  post_mean <- df %>%
    filter(between(time, 0, frame * 10)) %>%
    pull(cell_corr) %>%
    mean(na.rm = T)
    
  df <- df %>%
    mutate(gap_ratio = post_mean/pre_mean)

  return(df)
}

#################################
### Normalize and gather data ###
#################################

experiments <- experiments %>%
  map(calc_frap, pre = param_pre, frame = param_frame) %>% # calculate bg-corrected and normalized intensities
  map(bd, pre = param_pre, frame = param_frame) %>% # calculate bleach depth
  map(gr, pre = param_pre, frame = param_frame) # calculate gap ratio

# manually exclude experiments
experiments_excluded <- experiments[param_exclude]
experiments <- experiments[setdiff(seq_along(experiments), param_exclude)] # [-param_exclude] produces error on empty vector

recovery <- bind_rows(experiments, .id = 'id') %>%
  filter(bleach_depth > param_quality[1] & gap_ratio > param_quality[2]) %>% # limit data by bg/gr indicators
  mutate(from = 'experiment') %>%
  na.omit()

recovery_mean <- recovery %>%
  group_by(time) %>%
  summarise(recovery = mean(norm_full, na.rm = T),
            sd = sd(norm_full, na.rm = T),
            se = sd(norm_full)/length(norm_full),
            from = 'experiment') %>%
  na.omit() # NAs from bleach time and rows with only one experiment

recovery_excluded <- bind_rows(experiments_excluded, .id = 'id') %>%
  na.omit()