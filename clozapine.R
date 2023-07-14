
# Already done!
# instal l.packages("renv")
# library(renv)
# renv::activate()

# renv::install("keyring")
# renv::install("dplyr")
# renv::install("roux-ohdsi/ohdsilab")
# renv::snapshot()

# renv::install("OHDSI/ROhdsiwebApi")

# renv::install("OHDSI/CohortDiagnostics")

# downloadJdbcDrivers(
#   "redshift"
# )
# 
# Sys.setenv("DATABASECONNECTOR_JAR_FOLDER" = "D:/Users/d.harms/Documents")
# 



library(CohortDiagnostics)
library(keyring)
library(DatabaseConnector)
library(ohdsilab)
library(dplyr)
library(ROhdsiWebApi)
library(here)




cdmDatabaseSchema <- "omop_cdm_53_pmtx_202203"
my_schema <- "work_d_harms152"
cohort_table <- "clozapineAndTobacco"
database_id <- "databasename"
# vocabularyDatabaseSchema <- "omop_cdm_53_pmtx_202203"

outputFolder <- here("output")
exportFolder <- outputFolder
atlas_url <- "https://atlas.roux-ohdsi-prod.aws.northeastern.edu/WebAPI"
db_url <- "ohdsi-lab-redshift-cluster-prod.clsyktjhufn7.us-east-1.redshift.amazonaws.com/ohdsi_lab"
cohortIds <- c(2379)

###################################################################
connectionDetails <- createConnectionDetails(dbms="redshift",
                                             server= db_url,
                                             user="d_harms152",
                                             password="OwSO83UM2Qwm",
                                             port=5439,
                                             pathToDriver = file.path("D:/Users/d.harms/Documents/redshift"))

####################################################################




ROhdsiWebApi::authorizeWebApi(atlas_url, 
                              authMethod = "db", 
                              webApiUsername = "d_harms1157",
                              webApiPassword = "OwSO83UM2Qwm"
                              )
# list of cohort ids

cohortDefinitionSet <- ROhdsiWebApi::exportCohortDefinitionSet(baseUrl = atlas_url,
                                                               cohortIds = cohortIds,
                                                               generateStats = TRUE)

cohortTableNames <- CohortGenerator::getCohortTableNames(cohortTable = cohort_table)

CohortGenerator::createCohortTables(connectionDetails = connectionDetails,
                                    cohortTableNames = cohortTableNames,
                                    cohortDatabaseSchema = my_schema,
                                    incremental = FALSE)



CohortGenerator::generateCohortSet(connectionDetails= connectionDetails,
                                   cdmDatabaseSchema = cdmDatabaseSchema,
                                   cohortDatabaseSchema = my_schema,
                                   cohortTableNames = cohortTableNames,
                                   cohortDefinitionSet = cohortDefinitionSet,
                                   incremental = FALSE)



# con =  DatabaseConnector::connect(
#   dbms = "redshift",
#   server = "ohdsi-lab-redshift-cluster-prod.clsyktjhufn7.us-east-1.redshift.amazonaws.com/ohdsi_lab",
#   port = 5439,
#   user = "d_harms152",
#   password = "OwSO83UM2Qwm"
# )
# class(con)

executeDiagnostics(cohortDefinitionSet,
                   connectionDetails = connectionDetails,
                   cohortTable = cohortTable,
                   cohortDatabaseSchema = cohortDatabaseSchema,
                   cdmDatabaseSchema = cdmDatabaseSchema,
                   exportFolder = exportFolder,
                   databaseId = "database_schema",
                   minCellCount = 5)


preMergeDiagnosticsFiles(exportFolder)
launchDiagnosticsExplorer(dataFolder = exportFolder, dataFile = "Premerged.RData")

