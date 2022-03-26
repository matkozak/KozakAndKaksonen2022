######################
### Load libraries ###
######################

library(tidyverse)

########################
### Define variables ###
########################

# check if param_frame is defined
if (exists("param_frame") == 0) {
  stop("Please define param_frame before running the code.") # should be single numeric value
}

#################
### Load data ###
#################

patch_list <- dir(pattern = "_patch.txt")
cell_list <- dir(pattern = "_cell.txt")
bg_list <- dir(pattern = "_background.txt")

experiments <- list()

for (i in seq_along(patch_list)) {
  # read all data tables
  patch_table <- read.table(patch_list[i], col.names = "patch")
  cell_table <- read.table(cell_list[i], col.names = "cell")
  bg_table <- read.table(bg_list[i], col.names = "background")
  
  # determine bleach frame
  bleach = which.max(patch_table$patch)
  
  # create time variable
  prec <- nchar(strsplit(as.character(param_frame), "\\.")[[1]][2]) # number of digits in param_frame
  time <- seq((-bleach - param_rm) * param_frame,
              param_frame * (nrow(patch_table) - (bleach + 1 + param_rm)),
              by = param_frame) %>%
    round(prec)
  experiment <- bind_cols(time = time, patch_table, cell_table, bg_table)
  experiment[bleach:(bleach + param_rm), 2:4] <- NA
  experiments[[i]] <- experiment
}

# clean up
names(experiments) <- substr(patch_list, 1, 19)
rm(list = setdiff(ls(), ls(pattern = "experiments|param")))

# save image with data
save.image(file = paste(substr(names(experiments[1]), 1, 16), ".RData", sep = ""))