##################
### Fit limits ###
##################

# establish time limits for fitting the model
# should be a vector with two numerical values
# typically 0 and the maximum time when averaged data is still reliable
if (exists("param_fit") == 0) {
  stop("Please define param_fit before running the code.")
}

# param_fit <- c(0,60)

###############################################
### Fit single exponential to mean recovery ###
###############################################

expFRAP <- function (t, I0, A, k) {
  I0 - A * exp(-k * t)
}

fitFRAP <- function(df, begin = 1, finish = nrow(df)) {
  nls(recovery ~ expFRAP(t = time, I0, A, k),
      data = df[begin:finish, ],
      start = list(I0 = 0.1, A = 0.5, k = 0.1))
}

# do the fit
fitted_mean <- selected_patches_mean %>%
  filter(between(time, param_fit[1], param_fit[2])) %>%
  fitFRAP()

fit_all <- selected_patches %>%
  rename(recovery = norm_full) %>% # fitFRAP needs recovery variable, give it recovery
  select(id, time, recovery) %>% # only take the needed variables
  filter(between(time, param_fit[1], param_fit[2])) %>% # filter to fit limits
  fitFRAP()

print(summary(fitted_mean))

# get the model parameters
fitted_mean_coefs <- coef(fitted_mean)
mf <- fitted_mean_coefs[1]
t_half <- unname(log(2)/fitted_mean_coefs[3])

# get the number of averaged events
n_events <- selected_patches %>% select(id) %>% n_distinct()

# extract and average bleach depth
bd_mean <- selected_patches %>%
  group_by(id) %>%
  distinct(bleach_depth) %>%
  pull(bleach_depth) %>%
  {c(mean(.), sd(.))} %>% # braces {] prevent pipe from passing all values as first argument
  signif(2) # round to 2 significant digits

# save model parameters to a .txt file
sink('summary.txt')
cat('Mobile fraction:', mf,
    '\nHalf-time:', t_half,
    '\n\nNumber of averaged events:', n_events,
    '\n\nAverage bleach depth:', bd_mean[1],'+/-', bd_mean[2], 'SD',
    '\n\n-----------\nFit summary\n-----------\n',
    append=TRUE)
print(summary(fitted_mean))
sink()

########################
### Predict recovery ###
########################

# predict recovery based on fit coefficients
fit = tibble(time = round(seq(param_fit[1], param_fit[2], param_frame), 2),
             recovery = predict(fitted_mean), from = 'predicted')

# merge them together
selected_patches_mean <- bind_rows(selected_patches_mean, fit)