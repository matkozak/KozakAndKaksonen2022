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

# param_frame <- 0.53

#rm(list = setdiff(ls(), ls(pattern = "param_frame")))

#################
### Load data ###
#################

# create a list of files with 'GFP' or 'RFP' in working directory
gfp_list <- dir(pattern = "GFP.*txt$")
rfp_list <- dir(pattern = "RFP.*txt$")

# initialise a list for patch values
all_patches <- list()

# initialise a list for bleach times
bleach_frames <- list()

# loop to load data from each file to a data frame
# then add the data frame to a list (all_patches)
# write the frame of bleach (GFP maximum) into bleach_frames list
for (i in seq_along(gfp_list)) {
  series <- substr(gfp_list[i], 1, 19)
  gfp_table <- read.table(gfp_list[i], col.names="GFP")
  rfp_table <- read.table(rfp_list[i], col.names="RFP")
  
  bleach <- which.max(gfp_table$GFP)
  
  # create time variable
  prec <- nchar(strsplit(as.character(param_frame), "\\.")[[1]][2]) # number of digits in param_frame
  time <- seq(-bleach*param_frame, param_frame*(nrow(gfp_table) - (bleach + 1)),
              by = param_frame) %>%
    round(prec)
  
  patch <- bind_cols(tibble(time = time, bleach_frame = bleach),
                     gfp_table, rfp_table)
  
  # writes the time of bleach from current series to bleach_frames
  bleach_frames[[series]] <- bleach_frames[[series]] %>%
    append(bleach) %>%
    unique()
  
  # add the data frame to list of data frames
  all_patches[[i]] <- patch
}

# add experiment names from data filenames
names(all_patches) <- gfp_list %>%
  gsub('.txt', '', .) %>%
  gsub('_GFP_BS', '', .)

############################
### Remove bleach frames ###
############################

# use grep to find names of bleach_frames in all_patches and return index
# returns a list of as many vectors as there is images 
# each vector contains the id's of patches in all_patches list which belong to the same image
image_groups <- map(names(bleach_frames), grep, x = names(all_patches))

# this loop is a bit complex
# goes through image groups
# for each patch data frame within one group, GFP and RFP channels are NA'd at ALL frames 
for (i in seq_along(image_groups)) {
  for (j in image_groups[[i]]){
    all_patches[[j]][bleach_frames[[i]],3:4] <- NA
    }
}

all_patches <- map(all_patches, gather, 'channel', 'intensity', c(GFP, RFP))

# clean up
rm(list = setdiff(ls(), ls(pattern = "param_|patches")))