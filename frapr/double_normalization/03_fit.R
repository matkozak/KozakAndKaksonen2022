##################
### Fit limits ###
##################

# establish time limits for fitting the model
# should be a vector with two numerical values
# typically 0 and the maximum time when averaged data is still reliable
param_fit <- c(0, max(recovery_mean$time))

if (exists("param_fit") == 0) {
  stop("Please define param_fit before running the code.")
}

##########################################
### Define single exponential function ###
##########################################

expFRAP <- function (t, I0, A, k) {
  I0 - A * exp(-k * t)
}

fitFRAP <- function(df, begin = 1, finish = nrow(df), nls_c = nls.control()) {
  nls(recovery ~ expFRAP(t = time, I0, A, k),
      data = df[begin:finish, ],
      start = list(I0 = 0.1, A = 0.5, k = 0.1),
      control = nls_c)
}

###############################################
### Fit single exponential to mean recovery ###
###############################################

# do the fit
fit_mean <- recovery_mean %>%
  filter(between(time, param_fit[1], param_fit[2])) %>%
  fitFRAP()

print(summary(fit_mean))

# get the model parameters
coefs_mean <- coef(fit_mean)
mf <- coefs_mean[1]
t_half <- unname(log(2)/coefs_mean[3])

# get the number of events averaged and events excluded by bleach depth and gap ratio
n_events <- recovery %>% select(id) %>% n_distinct()
n_excluded <- length(experiments) - n_events

# extract and average bleach depth
bd <- recovery %>%
  group_by(id) %>%
  distinct(bleach_depth) %>%
  pull(bleach_depth) %>%
  {c(mean(.), sd(.))} %>% # braces {] prevent pipe from passing all values as first argument
  signif(2) # round to 2 significant digits

# extract and average gap ratio
gr <- recovery %>%
  group_by(id) %>%
  distinct(gap_ratio) %>%
  pull(gap_ratio) %>%
  {c(mean(.), sd(.))} %>% # braces {] prevent pipe from passing all values as first argument
  signif(2) # round to 2 significant digits

# save model parameters to a .txt file
sink('summary.txt')
cat('Mobile fraction:', mf,
    '\nHalf-time:', t_half,
    '\n\nNumber of averaged events:', n_events,
    '\nBleach gap cut-off:', param_quality[1], ', gap ratio cut-off:', param_quality[2],
    '\nNumber of events excluded by bleach depth or gap ratio:', n_excluded,
    '\nManually excluded:', length(param_exclude),
    '\n\nAverage bleach depth:', bd[1],'+/-', bd[2], 'SD',
    '\nAverage gap ratio:', gr[1],'+/-', gr[2], 'SD',
    '\n\n-----------\nFit summary\n-----------\n',
    append=TRUE)
print(summary(fit_mean))
sink()

############################################
### Fit single exponential to all points ###
############################################

fit_all <- recovery %>%
  rename(recovery = norm_full) %>% # fitFRAP needs recovery variable, give it recovery
  select(id, time, recovery) %>% # only take the needed variables
  filter(between(time, param_fit[1], param_fit[2])) %>% # filter to fit limits
  fitFRAP()

###############################################
### Fit single exponential to each recovery ###
###############################################

# VERY failure prone if the data is not good

fit_each <- recovery %>%
  rename(recovery = norm_full) %>% # fitFRAP needs recovery variable, give it recovery
  select(id, time, recovery) %>% # only take the needed variables
  group_by(id) %>%
  filter(between(time, param_fit[1], param_fit[2])) %>% # filter to fit limits
  do(mod = safely(fitFRAP)(.)$result) %>% # creates the fit; safely() sets value to NULL if nls throws a warning
  mutate(I0 = ifelse(!is.null(mod), coef(mod)[1], NA), # get the parameters out if not NULL, set to NA if NULL
         A = ifelse(!is.null(mod), coef(mod)[2], NA),
         k = ifelse(!is.null(mod), coef(mod)[3], NA),
  )

coefs_each <- fit_each %>%
  ungroup() %>%
  filter(I0<1) %>%
  summarise_at(vars(-c(id, mod)), funs(mean, sd), na.rm = T)

########################
### Predict recovery ###
########################

# time_windows has to be a df with a column 'time'
# so that predict function does not multiply scope (newdata param)
time_window <- tibble(time = round(seq(param_fit[1], param_fit[2], param_frame), 3))

# predict recovery based on fit coefficients
predict_mean <- tibble(time = time_window$time,
                       recovery = predict(fit_mean),
                       from = 'predicted')

# merge experimental and predicted data
recovery_mean <- bind_rows(recovery_mean, predict_mean)

predict_all <- tibble(time = time_window$time,
                      recovery = predict(fit_all, newdata = time_window, interval = 'prediction', level = 0.95),
                      from = 'predicted')