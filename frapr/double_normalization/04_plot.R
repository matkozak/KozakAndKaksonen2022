####################################
### Load libraries and set theme ###
####################################

#library(extrafont)

theme_frap <- function(base_size = 11, base_family = "",
                       base_line_size = base_size / 22,
                       base_rect_size = base_size / 22) {
  # minimal theme with border
  # based on theme_linedraw without the grid lines
  # also trying to remove all backgrounds but plot_background does not react to blank
  theme_linedraw(
    base_size = base_size,
    base_family = base_family,
    base_line_size = base_line_size,
    base_rect_size = base_rect_size
  ) %+replace%
    theme(
      # no grid and no backgrounds if I can help it
      plot.background = element_blank(),
      panel.background = element_blank(),
      panel.grid = element_blank(),
      plot.margin = margin(0, 0, 0, 0),
      complete = TRUE
    )
}

################
### Raw data ###
################

plot_raw <- recovery %>%
  select(id, time, patch, cell, background) %>%
  ggplot(aes(time))+
  geom_line(aes(y = patch, colour = 'patch'))+
  geom_line(aes(y = cell, colour = 'cell'))+
  geom_line(aes(y = background, colour = 'background'))+
  theme_frap()+
  labs(y="Raw intensity (a. u.)", x = 'Time (s)')+
  #  xlim(-10,75)+
  #  ylim(0,2)+
  facet_wrap(~id)

print(plot_raw)
ggsave('plot_raw.pdf', device = cairo_pdf, width = 8, height = 6)

##################################
### Individual recovery curves ###
##################################

plot_all <- recovery %>%
  select(id, time, norm_full) %>%
  ggplot(aes(time, norm_full))+
    geom_line()+
    theme_frap()+
    labs(y="Normalized intensity (a. u.)", x = 'Time (s)')+
  #  xlim(-10,75)+
  #  ylim(0,2)+
    facet_wrap(~id)

print(plot_all)
ggsave('plot_all.pdf', device = cairo_pdf, width = 12, height = 9)

if (length(param_exclude > 0)) {
plot_excluded <- recovery_excluded %>%
  select(id, time, norm_full) %>%
  ggplot(aes(time, norm_full))+
    geom_line()+
    theme_frap()+
    labs(y="Normalized intensity (a. u.)", x = 'Time (s)')+
    facet_wrap(~id)

print(plot_excluded)
ggsave('plot_excluded.pdf', device = cairo_pdf, width = 8, height = 6)
}

#####################
### Mean recovery ###
#####################

### BASE

plot_base <- recovery %>%
  select(time, norm_full, from) %>%
  ggplot(aes(time, norm_full))+
  # theme defined in theme_frap function
  theme_frap(base_size = 18, base_family = "Myriad Pro")+
  labs(x="Time (s)", y = "Fluorescence recovery (%)", title = 'FRAP of Ede1 condensates')+
  scale_color_brewer(palette = "Set2")+
  scale_y_continuous(breaks = seq(0, 1.6, 0.2),
                     labels = scales::label_percent(suffix = ''))+ # for percentage display
  coord_cartesian(ylim = c(0, 1.1)) + # limit set by coord_cartesian does not exclude data
  scale_x_continuous(limits = c(-5,75),
                     expand = c(0, 0),
                     breaks = seq(0,80,10))

### WITHOUT FIT

plot_mean <- plot_base +
  stat_summary(fun.y = mean, geom = 'line', na.rm = T)+
  stat_summary(fun.data = 'mean_sdl',
               fun.args = list(mult = 1), # mult = how many deviations
               geom = 'ribbon', alpha = 0.3, na.rm = T)

print(plot_mean)
ggsave('plot_mean.pdf', device = cairo_pdf, width = 160, height = 120, units = 'mm')

### WITH FIT

plot_mean_fit <- plot_mean + 
  geom_line(data = predict_mean,
            aes(y = recovery, colour = from),
            show.legend = F)

print(plot_mean_fit)
ggsave('plot_mean_fit.pdf', device = cairo_pdf, width = 160, height = 120, units = 'mm')

### ALL POINTS WITH FIT

plot_all_fit <- plot_base + 
  geom_point(aes(colour = from), show.legend = F, alpha = 0.1) + 
  geom_line(data = predict_all,
            aes(y = recovery, colour = from),
            show.legend = F)

print(plot_all_fit)
ggsave('plot_all_fit.pdf', device = cairo_pdf, width = 160, height = 120, units = 'mm')
