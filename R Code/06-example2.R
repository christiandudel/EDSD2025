### Birth register data #############################################

### Loading packages ################################################

  # For pipes etc
  library(tidyverse)
  # For handling of large data sets
  library(data.table)
  # For downloading data
  library(httr)


### Loading data ####################################################

  # Data available from:
  # https://www.nber.org/data/vital-statistics-natality-data.html
  
  # Data for 2023
  url <- "https://data.nber.org/nvss/natality/csv/2023/natality2023us.csv"
  # Documentation:
  # https://data.nber.org/nvss/natality/inputs/pdf/2023/UserGuide2023.pdf
  
  # Download, the file is around 2GB, might take some time
  file1 <- "U:/Data/natality2023us.csv"
  if(!file.exists(file1)) {
    GET(url,write_disk(file1, overwrite = TRUE), progress() )
  }
  
  # Load & save downloaded file
  file2 <- "U:/Data/usregister.Rdata"
  if(!file.exists(file2)) {
    dat <- fread(file1,select=c("restatus",
                                "mager","fagecomb",
                                "dbwt",
                                "cig_1","cig_2","cig_3",
                                "dob_mm"))
    save(dat,file=file2)
  }
  
  # Load
  load(file2)


### Editing data ####################################################

  # Select & rename variables
  dat <- dat |> rename(mage=mager, # mother's age
                       fage=fagecomb, # father's age
                       weight=dbwt, # birth weight in grams
                       resident=restatus) # residency status
  
  # Drop if not resident
  dat$resident |> table()
  dat <- dat |> filter(resident!=4)
  
  # Age of father
  dat$fage %>% summary
  dat$fage %>% table %>% barplot
  dat$mage %>% summary
  dat <- dat %>% mutate(fage=ifelse(fage==99,
                                    mager+3,
                                    fage))
  
  # Restrict age range
  summary(dat)
  dat <- dat |> filter(mage%in%15:49 & fage%in%15:59)



### Get population data for fertility rates #########################

  # Load library
  library(HMDHFDplus)
  # Gets data from the HMD: https://www.mortality.org/
  
  # Set username and password
  # us <- "username"
  # pw <- "password"
  
  # Load US data
  pop <- readHMDweb(CNTRY="USA",
                    item="Exposures_1x1",
                    username=us,
                    password=pw)
  
  # Edit pop data
  pop <- pop %>%
    filter(Year==2023) %>%
    select(Age,Female,Male)


### Generate rates for men ##########################################

  # Aggregate data
  dat$count <- 1
  counts_m <- aggregate(count~fage,data=dat,FUN=sum)
  dim(counts_m)
  head(counts_m)
  counts_m <- counts_m %>% rename('Age'="fage")
  
  # Combine data
  rates_m <- tibble(Age=15:59) %>% left_join(counts_m,by="Age")
  rates_m <- pop %>% 
             select(Age,Male) %>% 
             right_join(rates_m,by="Age")
  
  # Calculate rates
  rates_m <- rates_m %>% mutate(rate=count/Male)
  
  # TFR
  rates_m %>% summarize(TFR=sum(rate))
  
  # MAC
  rates_m %>% summarize(MAC=sum(Age*rate/sum(rate)))
  
  # Simple plot of age schedule
  ggplot(data=rates_m,aes(x=Age,y=rate)) +
    geom_line()


### Another simple analysis: Smoking comparison with birthwt ########

  # Create dummy for smoking status
  dat <- dat %>% mutate(dcig1 = ifelse(cig_1%in%1:98,1,0),
                        dcig2 = ifelse(cig_2%in%1:98,1,0),
                        dcig3 = ifelse(cig_3%in%1:98,1,0),
                        dcig  = dcig1+dcig2+dcig3,
                        dcig  = ifelse(dcig>0,1,0),
                        dcig  = ifelse(cig_1==99,NA,dcig),
                        dcig  = ifelse(cig_2==99,NA,dcig),
                        dcig  = ifelse(cig_3==99,NA,dcig))

  # Smoking prevalence in 2023
  dat$dcig %>% table(useNA="always") %>% prop.table
  dat$dcig %>% table %>% prop.table

  # Smoking prevalence in birthwt data from MASS
  data(birthwt,package="MASS")
  birthwt$smoke %>% table %>% prop.table


### Another simple analysis: Seasonality of births ##################

  # For 'label_number'
  library(scales)

  # Plot month of birth
  ggplot(data=dat,
         mapping=aes(x=dob_mm))+
    geom_bar(stat="count",
             color="black",
             fill="steelblue") +
    labs(x="Birth month",y="Number of births",
         title="Seasonality of births")+
    scale_x_discrete(limits=paste(1:12))+
    scale_y_continuous(labels = label_number(suffix = " T", scale = 1e-3))
  