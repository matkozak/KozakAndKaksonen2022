####################################
### Load libraries and set theme ###
####################################

#library(extrafont)

theme_frap <- function(base_size = 11, base_family = "",
                        base_line_size = base_size / 22,
                        base_rect_size = base_size / 22) {
  # minimal theme with border
  # based on theme_linedraw without the grid lines
  # also trying to remove all backgrounds but plot_background won't set to blank
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

####################################
### Individual patch intensities ###
####################################

plot_ind_norm <- ggplot(selected_patches, aes(time , stats::filter(normalized, rep(1/5, 5))))+ # running average smoothing
  geom_line(aes(colour = channel))+
  scale_colour_manual(values = c("#009E73","#CC79A7"))+ # color scale to match fluorophores
  labs(y="Normalized intensity (a. u.)", x = 'Time (s)')+
  theme_frap()+
  coord_cartesian(xlim = c(-10, 200), ylim = c(0,2))+ # y limit set by coord_cartesian does not exclude data
  #theme(strip.text = element_text(size = 10))+
  facet_wrap(~id)#, labeller(id = label_wrap_gen(width = 10))) # for wrapping facet labels

print(plot_ind_norm)
ggsave('plot_individual_norm.pdf', device = cairo_pdf, width = 240, height = 180, units = 'mm')

plot_ind_raw <- ggplot(selected_patches, aes(time , stats::filter(intensity, rep(1/5, 5))))+ # running average smoothing
  geom_line(aes(colour = channel))+
  scale_colour_manual(values = c("#009E73","#CC79A7"))+ # color scale to match fluorophores
  labs(y="Fluorescence intensity (a. u.)", x = 'Time (s)')+
  theme_linedraw()+
  coord_cartesian(xlim = c(-10, 200))+ # y limit set by coord_cartesian does not exclude data
  scale_x_continuous(minor_breaks = seq(-10 , 200, 10))+
  #theme(strip.text = element_text(size = 10))+
  facet_wrap(~id)#, labeller(id = label_wrap_gen(width = 10))) # for wrapping facet labels

print(plot_ind_raw)
ggsave('plot_individual_raw.pdf', device = cairo_pdf, width = 240, height = 180, units = 'mm')

##############################
### Mean recovery with fit ###
##############################

plot_fit <- ggplot(selected_patches_mean, aes(time, recovery))+
  geom_line(aes(color = from))+
  #geom_line(aes(y = Fit), color = 'blue')+
  # 95% CI ribbon
  # geom_ribbon(aes(ymin = recovery-1.96 * se,
  #                 ymax = recovery + 1.96 * se,
  #                 fill="red"),
  #             alpha=0.3)+ # non-aes options go here
  # SD ribbon
  geom_ribbon(aes(ymin = recovery - sd,
                  ymax = recovery + sd,
                  fill = from),
              alpha=0.3)+ # non-aes options go here
  # theme defined in theme_frap function
  theme_frap(base_size = 24, base_family = "Myriad Pro")+
  labs(x="Time (s)", y = paste("Mean recovery (+/-SD, n=", n_events, ")", sep = ""))+
  guides(fill = FALSE, colour = FALSE)+
  scale_y_continuous(breaks = seq(0, 1.6, 0.2))+ # setting limits within scale excludes data
  coord_cartesian(ylim = c(0,1.5))+ # y limit set by coord_cartesian does not exclude data
  scale_x_continuous(limits = c(-5,85), expand = c(0, 0), breaks = seq(0,80,10))

print(plot_fit)
ggsave('plot_fit.pdf', device = cairo_pdf, width = 160, height = 120, units = 'mm')

#################################
### Mean recovery without fit ###
#################################

plot_mean <- selected_patches %>%
  filter(channel=='GFP') %>%
  select(time, norm_full) %>%
  ggplot(aes(time, norm_full))+
    stat_summary(fun.y = mean, geom = 'line', na.rm = T)+
    stat_summary(fun.data = 'mean_sdl', fun.args = list(mult = 1), geom = 'ribbon', alpha = 0.3, na.rm = T)+
    # theme defined in theme_frap function
    theme_frap(base_size = 18, base_family = "Myriad Pro")+
    #labs(x="Time (s)", y = paste("Mean recovery (+/-SD, n=", n_events, ")", sep = ""))+
    labs(x="Time (s)", y = "Fluorescence recovery (%)", title = 'FRAP of Ede1 endocytic sites')+
    scale_y_continuous(breaks = seq(0, 1.6, 0.2),
                       labels = scales::label_percent(suffix = ''))+ # for percentage display
    coord_cartesian(ylim = c(0,1.4))+ # y limit set by coord_cartesian does not exclude data
    scale_x_continuous(limits = c(-5,75), expand = c(0, 0), breaks = seq(0,80,10))

print(plot_mean)
ggsave('plot_mean.pdf', device = cairo_pdf, width = 160, height = 120, units = 'mm')