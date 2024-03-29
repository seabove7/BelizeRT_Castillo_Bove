################################################################################
################### Sample plasticity based on PC distances ####################
############## Written by Colleen B. Bove (colleenbove@gmail.com) ##############
########################## Laste update: 03 Feb 2022 ###########################
################################################################################

## Required packages to run:
# dplyr


## PC distances can be calculated from prcomp() objects or from plotcca()


## To run the function, enter the following objects:
# ccaplast(cca = XXX, # the cca dataframe containing the cca eigenvalues
#          data = XXX, # the condition/treatment data corresponding to samples
#          sample_ID = "XXX", # the name of column that provide unique ID per sample (if blank, will pull rownames for this)
#          num_cca =  "XXX", # the number of ccas to include in analysis (default is 'all', but you can specify another number with a minimum of 2 ccas)
#          control_col = "XXX", # what the 'treatment' column is called
#          control_lvl = "XXX", # control level of the treatment. If blank, a control mean per control level is assumed
#          group = "XXX") # the grouping column (i.e., colony). If blank, will assume control level grouping only!



########################################################################################

CCAplast <- function(cca, data, sample_ID = NA, num_cca = "all", control_col, control_lvl = "none", group = NA, keep_control = "no") {
  
  # rename the user input info
  cca_df <- cca
  data_df <- data
  control_name <- control_col
  control_lvl <- control_lvl
  group_col <- group
  keep <- keep_control

    cca_dist <- cca_df # grab CC distances from data.frame object

  
  
  # check for correct number of ccas provided
  if(class(num_cca) == "numeric") {
    if(num_cca < 2) { # will throw error if too few ccas requested
      stop("please select more than 2 PCs to calculate distance")
    } 
  }
  
  if(class(num_cca) == "numeric") {
    if(num_cca > (cca_dist %>% dplyr::select(starts_with("cca")) %>% ncol())) { # will throw error if too many ccas requested
      stop(paste(num_cca, "PCs requested for calculation, but only", (cca_dist %>% dplyr::select(starts_with("cca")) %>% ncol()), "PCs available. Select appropriate number of ccas for calculation."))
    } 
  }
  
  
  # oder the dataframe to ensure correct pairing after calculating distance 
  if(sample_ID %in% colnames(data_df)){
    data_df <- data_df[order(data_df[[sample_ID]]),]
  } else {
    data_df <- data_df[order(row.names(data_df)),]
  }
  
  
  # combine the datasets
  dist_df <- cbind(data_df, cca_dist) 
  
  
  # if there is no control level, modify so function pulls all levels
  if(control_lvl == "none") {
    control_lvl = levels(dist_df[[control_name]])
  } else {
    control_lvl = control_lvl
  }
  
  
  # make dataframe of control grouping only
  if(!is.na(group_col)) { # calculate mean per grouping ID (if provided)
    mean_control <- dist_df %>%
      filter(dist_df[[control_name]] == list(control_lvl)[[1]]) %>% 
      rename_with(tolower) %>% # renames all pc's with lowercase 'PC' (just to differentiate from all sample PCs)
      dplyr::select(colnames((dist_df %>% rename_with(tolower))[tolower(group_col)]), starts_with("cca"))
    
    # add the control cca values to treatment samples per grouping
    dist_df2 <- left_join(dist_df, mean_control, by.x = group_col, by.y = tolower(group_col))
    
  } else { # calculate mean per control treatment
    mean_control <- dist_df %>%
      filter(dist_df[[control_name]] == list(control_lvl)[[1]]) %>% 
      rename_with(tolower) %>% # renames all pc's with lowercase 'PC' (just to differentiate from all sample PCs)
      dplyr::select(colnames((dist_df %>% rename_with(tolower))[tolower(control_name)]), starts_with("cca")) %>% # select just the PCs 
      #group_by() 
      group_by_at(vars(tolower(control_name))) %>% 
      summarise_if(is.numeric, mean)
    
    # add the control cca values to all samples 
    dist_df2 <- merge(dist_df, mean_control %>% select(!control_name), all = TRUE)
    
  }
  
  
  
  # again, reorder data
  if(sample_ID %in% colnames(data_df)){
    dist_df2 <- dist_df2[order(dist_df2[[sample_ID]]),]
  } else {
    rownames(dist_df2) <- rownames(data_df)
    dist_df2 <- dist_df2[order(row.names(dist_df2)),]
  }
  
  
  ### Calculate sample (cca) distances from control (cca) using all ccas
  # make dataframe to populate with cca distances
  full_calc_dist <- data.frame(control_name = dist_df2[control_name])
  
  if(num_cca == "all") {
    ## forloop that will calculate distances between control and sample for all PCs (n will be total number)
    for(n in 1:(dist_df %>% dplyr::select(starts_with("CC")) %>% ncol())){
      # makes the cca column name for control (lowercase) and sample (uppercase)
      CC_col <- paste0("CCA", n)
      cc_col <- paste0("cca", n)
      
      # pulls the PC column for control (lowercase) and sample (uppercase)
      CCx <- dist_df2[CC_col]
      ccx <- dist_df2[cc_col]
      
      cca_calc_dist <- data.frame((CCx - ccx)^2) # calculates the distance between 2 CCs
      full_calc_dist <- cbind(full_calc_dist, cca_calc_dist) # add that distance to running dataframe
    }
  } else {
    ## forloop that will calculate distances between control and sample for SPECIFIED # of CCs (n will be total number)
    for(n in 1:as.numeric(num_cca)){
      # makes the PC column name for control (lowercase) and sample (uppercase)
      CC_col <- paste0("CCA", n)
      cc_col <- paste0("cca", n)
      
      # pulls the PC column for control (lowercase) and sample (uppercase)
      CCx <- dist_df2[CC_col]
      ccx <- dist_df2[cc_col]
      
      cca_calc_dist <- data.frame((CCx - ccx)^2) # calculates the distance between 2 CCs
      full_calc_dist <- cbind(full_calc_dist, cca_calc_dist) # add that distance to running dataframe
    }
  }
  
  
  ## final distance calculation (adds all cca distances and takes squareroot)
  distance <- full_calc_dist %>% 
    mutate(dis_sum = rowSums(across(where(is.numeric)))) %>% 
    mutate(dist = sqrt(dis_sum)) %>% 
    dplyr::select(matches("dist"))
  
  
  ## combine the calculated distance with the metadata and remove controls for final dataframe
  dist_df <- data_df %>% 
    bind_cols(distance) %>% 
    filter(!is.na(dist)) 
  
  ## removes the control levels (if desired)
  if((length(control_lvl) > 1) | keep == "yes"){
    dist_df <- dist_df
  } else {
    dist_df <- dist_df %>%
      filter(dist_df[[control_name]] != control_lvl) %>% 
      droplevels()
  }
  
}


#################################################################
###### Session information from last update

# R version 3.6.3 (2020-02-29)
# Platform: x86_64-apple-darwin15.6.0 (64-bit)
# Running under: macOS Catalina 10.15.7
# 
# Matrix products: default
# BLAS:   /System/Library/Frameworks/Accelerate.framework/Versions/A/Frameworks/vecLib.framework/Versions/A/libBLAS.dylib
# LAPACK: /Library/Frameworks/R.framework/Versions/3.6/Resources/lib/libRlapack.dylib
# 
# locale:
#   [1] en_US.UTF-8/en_US.UTF-8/en_US.UTF-8/C/en_US.UTF-8/en_US.UTF-8
# 
# attached base packages:
#   [1] stats     graphics  grDevices utils     datasets  methods   base     
# 
# loaded via a namespace (and not attached):
#   [1] fansi_0.5.0      assertthat_0.2.1 utf8_1.2.2       crayon_1.4.1     dplyr_1.0.7      R6_2.5.1         DBI_1.1.1       
# [8] lifecycle_1.0.0  magrittr_2.0.1   pillar_1.6.2     rlang_0.4.11     vctrs_0.3.8      generics_0.1.0   ellipsis_0.3.2  
# [15] tools_3.6.3      glue_1.4.2       purrr_0.3.4      tinytex_0.33     xfun_0.25        compiler_3.6.3   pkgconfig_2.0.3 
# [22] tidyselect_1.1.1 tibble_3.1.3   

