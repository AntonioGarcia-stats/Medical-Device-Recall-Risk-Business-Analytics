# ============================================================
# MEDICAL DEVICE RECALL PREDICTIVE RISK - SURVIVAL ANALYSIS
# ============================================================


 install.packages(c("readxl", "dplyr", "survival", "survminer",
                    "ggplot2", "broom", "litedown"))

library(readxl)
library(dplyr)
library(survival)
library(survminer)
library(ggplot2)
library(broom)


# ------------------------------------------------------------
# 1. READ DATA
# ------------------------------------------------------------

recalls <- read_excel("/recalls.csv.xlsx")

str(recalls)
summary(recalls)


# ------------------------------------------------------------
# 2. PREPARE VARIABLES
# ------------------------------------------------------------

recalls_model <- recalls %>%
  select(
    followup_days,
    event_observed,
    device_class,
    medical_specialty,
    root_cause_description,
    products_in_event,
    n_k_numbers,
    reason_length_chars
  ) %>%

  mutate(
    event_observed = as.numeric(event_observed),

    device_class = factor(device_class),

    medical_specialty = factor(medical_specialty),

    root_cause_description = factor(root_cause_description),

    products_in_event = as.numeric(products_in_event),

    n_k_numbers = as.numeric(n_k_numbers),

    reason_length_chars = as.numeric(reason_length_chars)
  ) %>%

  filter(
    !is.na(followup_days),
    !is.na(event_observed),
    !is.na(device_class),
    !is.na(medical_specialty),
    !is.na(root_cause_description)
  )


# Check final sample
dim(recalls_model)

table(recalls_model$event_observed)
table(recalls_model$device_class)







# ------------------------------------------------------------
# 3. OVERALL KAPLAN-MEIER CURVE
# ------------------------------------------------------------
#The following code is Kaplan - Meier Model
# Before prediction , we need to look at 
# the overall recall resolution behavior
# here
# S(t) = P(recall remains unresolved beyond time t)
# Hence, higher survival is worse from an operational perspective
km_all <- survfit(
  Surv(followup_days, event_observed) ~ 1,
  data = recalls_model
)

summary(km_all)

ggsurvplot(
  km_all,
  data = recalls_model,
  conf.int = TRUE,
  risk.table = TRUE,
  xlab = "Days Since Recall Initiation",
  ylab = "Probability Recall Remains Unresolved",
  title = "Overall Recall Resolution Survival Curve"
)





# ------------------------------------------------------------
# 4. KAPLAN-MEIER BY DEVICE CLASS
# ------------------------------------------------------------
#The following code is a Kaplan Meier by device class
# useful for building the predictive model


km_class <- survfit(
  Surv(followup_days, event_observed) ~ device_class,
  data = recalls_model
)

ggsurvplot(
  km_class,
  data = recalls_model,
  conf.int = TRUE,
  risk.table = TRUE,
  pval = TRUE,
  xlab = "Days Since Recall Initiation",
  ylab = "Probability Recall Remains Unresolved",
  title = "Recall Resolution by Device Class",
  legend.title = "Device Class"
)



# ------------------------------------------------------------
# 5. TRAIN / TEST SPLIT
# ------------------------------------------------------------
#The Following is an 80/20 Split

set.seed(1812)

n <- nrow(recalls_model)

train_index <- sample(
  1:n,
  size = round(0.80 * n)
)

train <- recalls_model[train_index, ]

test <- recalls_model[-train_index, ]


nrow(train)
nrow(test)



# ------------------------------------------------------------
# 6. COX PROPORTIONAL HAZARDS MODEL
# ------------------------------------------------------------

# In our following the model, the event defined is termination
# HR > 1 implies faster recall termination
# HR < 1 implies slower recall termination and prolonged risk

cox_model <- coxph(
  Surv(followup_days, event_observed) ~
    device_class +
    medical_specialty +
    root_cause_description +
    products_in_event +
    n_k_numbers +
    reason_length_chars,
  data = train,
  x = TRUE
)

summary(cox_model)


# ------------------------------------------------------------
# 7. HAZARD RATIO TABLE
# ------------------------------------------------------------

cox_results <- tidy(
  cox_model,
  exponentiate = TRUE,
  conf.int = TRUE
)

cox_results <- cox_results %>%
  select(
    term,
    estimate,
    conf.low,
    conf.high,
    p.value
  ) %>%

  rename(
    Hazard_Ratio = estimate,
    CI_Lower = conf.low,
    CI_Upper = conf.high,
    P_Value = p.value
  )

cox_results



##########################
#The following code exports the results for powerBI


write.csv(
  cox_results,
  "cox_recall_results.csv",
  row.names = FALSE
)

##########################


# ------------------------------------------------------------
# 9. PREDICT COX LINEAR PREDICTOR
# ------------------------------------------------------------

test$cox_score <- predict(
  cox_model,
  newdata = test,
  type = "lp"
)

summary(test$cox_score)


test$prolonged_risk_score <- -test$cox_score





# ------------------------------------------------------------
# 10. CREATE RISK GROUPS
# ------------------------------------------------------------

risk_cutoffs <- quantile(
  test$prolonged_risk_score,
  probs = c(1/3, 2/3),
  na.rm = TRUE
)

test <- test %>%
  mutate(
    risk_group = case_when(
      prolonged_risk_score <= risk_cutoffs[1] ~ "Low",
      prolonged_risk_score <= risk_cutoffs[2] ~ "Medium",
      prolonged_risk_score > risk_cutoffs[2] ~ "High"
    )
  )

test$risk_group <- factor(
  test$risk_group,
  levels = c("Low", "Medium", "High")
)

table(test$risk_group)





# ------------------------------------------------------------
# 11. KAPLAN-MEIER CURVES BY PREDICTED RISK
# ------------------------------------------------------------

km_risk <- survfit(
  Surv(followup_days, event_observed) ~ risk_group,
  data = test
)

ggsurvplot(
  km_risk,
  data = test,
  risk.table = TRUE,
  conf.int = TRUE,
  pval = TRUE,
  xlab = "Days Since Recall Initiation",
  ylab = "Probability Recall Remains Unresolved",
  title = "Recall Resolution by Predicted Risk Group",
  legend.title = "Predicted Risk"
)




# ------------------------------------------------------------
# 12. CONCORDANCE INDEX
# ------------------------------------------------------------

concordance_result <- concordance(
  Surv(followup_days, event_observed) ~
    predict(cox_model, newdata = test, type = "lp"),
  data = test,
  reverse = TRUE
)

concordance_result




# ------------------------------------------------------------
# 13. BASELINE SURVIVAL
# ------------------------------------------------------------

base_surv <- survfit(cox_model)

summary(
  base_surv,
  times = 365
)



# Predict survival curve for each test observation

surv_predictions <- survfit(
  cox_model,
  newdata = test
)


# for small number of observations
summary(
  surv_predictions,
  times = 365
)




# ------------------------------------------------------------
# 14. INDIVIDUAL 1-YEAR UNRESOLVED PROBABILITY
# ------------------------------------------------------------

baseline <- survfit(cox_model)

baseline_summary <- summary(
  baseline,
  times = 365,
  extend = TRUE
)

S0_365 <- baseline_summary$surv[1]

S0_365



test$linear_predictor <- predict(
  cox_model,
  newdata = test,
  type = "lp"
)

test$prob_unresolved_1yr <-
  S0_365 ^ exp(test$linear_predictor)



test %>%
  select(
    device_class,
    medical_specialty,
    root_cause_description,
    products_in_event,
    prob_unresolved_1yr
  ) %>%
  arrange(desc(prob_unresolved_1yr)) %>%
  head(20)



# ------------------------------------------------------------
# 15. BUSINESS RISK CLASSIFICATION
# ------------------------------------------------------------
#Converting probability into business risk categories

test <- test %>%
  mutate(
    risk_category = case_when(
      prob_unresolved_1yr < 0.40 ~ "Low",
      prob_unresolved_1yr < 0.70 ~ "Moderate",
      prob_unresolved_1yr >= 0.70 ~ "High"
    )
  )

table(test$risk_category)




#Creating a final PowerBI report
recalls_model <- recalls %>%
  select(
    product_res_number,
    res_event_number,
    recalling_firm_norm,
    initiated_year,
    followup_days,
    event_observed,
    device_class,
    medical_specialty,
    root_cause_description,
    products_in_event,
    n_k_numbers,
    reason_length_chars
  ) %>%

  mutate(
    event_observed = as.numeric(event_observed),
    device_class = factor(device_class),
    medical_specialty = factor(medical_specialty),
    root_cause_description = factor(root_cause_description)
  ) %>%

  filter(
    !is.na(followup_days),
    !is.na(event_observed),
    !is.na(device_class),
    !is.na(medical_specialty),
    !is.na(root_cause_description)
  )




write.csv(
  test,
  "medical_device_recall_predictions.csv",
  row.names = FALSE
)


##file checks
## not necessary for the project
##getwd()
##list.files(pattern = "medical_device_recall_predictions")

##head(test)
##names(test)