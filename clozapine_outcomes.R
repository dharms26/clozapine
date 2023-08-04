# Packages
library(keyring)
library(DatabaseConnector)
library(CDMConnector)
library(dplyr)
library(ohdsilab)
library(here)
library(CohortGenerator)


# Credentials

usr = keyring::key_get("lab_user")
pw  = keyring::key_get("lab_password")
atlas_url = "https://atlas.roux-ohdsi-prod.aws.northeastern.edu/WebAPI"
cohortId = c(2776, 2609, 2774, 2775, 2379)

# DB Connections
base_url = "https://atlas.roux-ohdsi-prod.aws.northeastern.edu/WebAPI"
cdm_schema = "omop_cdm_53_pmtx_202203"
my_schema = paste0("work_", keyring::key_get("lab_user"))

# Create the connection
con =  DatabaseConnector::connect(dbms = "redshift",
                                  server = "ohdsi-lab-redshift-cluster-prod.clsyktjhufn7.us-east-1.redshift.amazonaws.com/ohdsi_lab",
                                  port = 5439,
                                  user = keyring::key_get("lab_user"),
                                  password = keyring::key_get("lab_password"))


# check connection
class(con)

# defaults to help with querying
options(con.default.value = con)
options(schema.default.value = cdm_schema)
options(write_schema.default.value = my_schema)


# Create connection details
connectionDetails <- createConnectionDetails(dbms = "redshift",
                                             server = "ohdsi-lab-redshift-cluster-prod.clsyktjhufn7.us-east-1.redshift.amazonaws.com/ohdsi_lab",
                                             port = 5439,
                                             user = keyring::key_get("lab_user"),
                                             password = keyring::key_get("lab_password"))

ROhdsiWebApi::authorizeWebApi(atlas_url, 
                              authMethod = "db", 
                              webApiUsername = "d_harms1157", 
                              webApiPassword = keyring::key_get("lab_password"))

cohortDefinitionSet <- ROhdsiWebApi::exportCohortDefinitionSet(baseUrl = atlas_url,
                                                               cohortIds = cohortId)

cohortDefinitionSet

cohortTableNames <- getCohortTableNames(cohortTable = "clozapine_project")
cohortTableNames

# create empty tables in the {mySchema}.cohort table
createCohortTables(connectionDetails = connectionDetails,
                   cohortTableNames = cohortTableNames,
                   cohortDatabaseSchema = my_schema)

cohortsGenerated <- generateCohortSet(connectionDetails = connectionDetails,
                                      cdmDatabaseSchema = cdm_schema,
                                      cohortDatabaseSchema = my_schema,
                                      cohortTableNames = cohortTableNames,
                                      cohortDefinitionSet = cohortDefinitionSet)

################### OK NOW DO STUFF LOCALLY ###################

# Create one table with all five cohorts

cohorts = tbl(con, inDatabaseSchema(my_schema, "clozapine_project")) %>% collect()

head(cohorts)

# mutate table to have 1 column for each cohort

cohort_wide = cohorts %>%
  mutate(cohort = case_when(
    cohort_definition_id  == 2776 ~ "comparator",
    cohort_definition_id  == 2379 ~ "target",
    cohort_definition_id  == 2609 ~ "relapse",
    cohort_definition_id  == 2774 ~ "clean",
    cohort_definition_id  == 2775 ~ "persistent"
  )) %>%
  # delete unnecessary columns
  select(-cohort_definition_id, -cohort_start_date, -cohort_end_date) %>% 
  mutate(value = 1) %>%
  tidyr::pivot_wider(names_from = cohort, values_from = value) %>%
  select(subject_id, target, comparator, clean, relapse, persistent) %>%
  # only keep members of outcome or comparator cohort
  filter(!is.na(target) | !is.na(comparator))

# define sub-tables with certain outcomes within target cohort
target_clean <- cohort_wide %>%
  filter(target==1 & clean==1)
target_relapse <- cohort_wide %>%
  filter(target==1 & relapse==1)
target_persistent <- cohort_wide %>%
  filter(target==1 & persistent==1)
target_tot <- cohort_wide %>%
  filter(target==1)

# sum members of each outcome cohort
target_clean_ct <- sum(target_clean$target)
target_relapse_ct <- sum(target_relapse$target)
target_persistent_ct <-  sum(target_persistent$target)
target_tot_ct <- sum(target_tot$target)

# Same process for comparator cohort
comp_clean <- cohort_wide %>%
  filter(comparator==1 & clean==1)
comp_relapse <- cohort_wide %>%
  filter(comparator==1 & relapse==1)
comp_persistent <- cohort_wide %>%
  filter(comparator==1 & persistent==1)
comp_tot <- cohort_wide %>%
  filter(comparator==1)

comp_clean_ct <- sum(comp_clean$comparator)
comp_relapse_ct <- sum(comp_relapse$comparator)
comp_persistent_ct <-  sum(comp_persistent$comparator)
comp_tot_ct <- sum(comp_tot$comparator)

# create data frame with results
outcome_breakdown <- data.frame("targ/comp" = c("target", "target", "target",
                                                "comparator", "comparator", "comparator"),
                                
                                "outcome" = c("clean", "relapse", "persistent", 
                                              "clean", "relapse", "persistent"),
                        
                                "percentage" = round(100*c(target_clean_ct/target_tot_ct,
                                                     target_relapse_ct/target_tot_ct,
                                                     target_persistent_ct/target_tot_ct,
                                                     comp_clean_ct/comp_tot_ct,
                                                     comp_relapse_ct/comp_tot_ct,
                                                     comp_persistent_ct/comp_tot_ct), digits = 1))

