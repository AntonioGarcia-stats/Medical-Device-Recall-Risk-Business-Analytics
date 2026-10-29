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
library(forcats)
library(patchwork)
library(survival)
library(splines)
library(car)      




# ------------------------------------------------------------
# 1. READ DATA
# ------------------------------------------------------------

recalls <- read_excel(".../recalls.csv.xlsx")

str(recalls)
summary(recalls)


# ------------------------------------------------------------
# 2. PREPARE VARIABLES
# ------------------------------------------------------------

# Selecting relevant variables
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

# Assigning variables as nuumeric or factor accordingly.
  mutate(
    event_observed = as.numeric(event_observed),

    device_class = factor(device_class),

    medical_specialty = factor(medical_specialty),

    root_cause_description = factor(root_cause_description),

    products_in_event = as.numeric(products_in_event),

    n_k_numbers = as.numeric(n_k_numbers),

    reason_length_chars = as.numeric(reason_length_chars)
  ) %>%

#Removing missing values
  filter(
   complete.cases(
    followup_days,
    event_observed,
    device_class,
    medical_specialty,
    root_cause_description,
    products_in_event,
    n_k_numbers,
    reason_length_chars
  ))

#Collapse sparse categories in "Other" for root cause description
recalls_model <- recalls_model %>%
 mutate(
 root_cause_description = fct_lump_min(
 root_cause_description,
 min = 10,
 other_level = "Other"
 )
)


# Collapse sparse device classes (combining class 3 and class N)
recalls_model <- recalls_model %>%
  mutate(
    device_class = case_when(
      device_class %in% c("3", "N") ~ "Other",
      TRUE ~ as.character(device_class)
    ),
    device_class = factor(device_class)
  )



# Collapse sparse medical specialty categories
recalls_model <- recalls_model %>%
  mutate(
    medical_specialty = fct_lump_min(
      medical_specialty,
      min = 10,
      other_level = "Other"
    )
  )


# Check final sample ( N= 404, 8 variables)
dim(recalls_model)


# Frequency and Relative Frequency Table
freq_table <- function(data, variable) {
  data %>%
    count({{ variable }}, name = "Frequency") %>%
    mutate(
      Relative_Frequency = Frequency / sum(Frequency),
      Percent = Relative_Frequency * 100
    )
}

event_table <- freq_table(recalls_model, event_observed)

device_table <- freq_table(recalls_model, device_class)

specialty_table <- freq_table(recalls_model, medical_specialty)

root_cause_table <- freq_table(recalls_model, root_cause_description)


event_table
device_table
specialty_table
root_cause_table



# ------------------------------------------------------
# 3. DESCRIPTIVE STATISTICS
# ------------------------------------------------------
# Histograms for "products in event", " Number of K numbers", "Reason length"
# Variable: Products in event
p5 <- ggplot(recalls_model, aes(x = products_in_event)) +
  geom_histogram(
    binwidth = 1,
    boundary = 0,
    fill = "steelblue",
    color = "black"
  ) +
  stat_bin(
    binwidth = 1,
    boundary = 0,
    geom = "text",
    aes(label = after_stat(ifelse(count > 0, count, ""))),
    vjust = -0.3,
    size = 3
  ) +
  labs(
    title = "Products in Event",
    x = "Products in Event",
    y = "Frequency"
  ) +
  theme_minimal()


# Variable: Number of K numbers
p6 <- ggplot(recalls_model, aes(x = n_k_numbers)) +
  geom_histogram(
    binwidth = 1,
    boundary = 0,
    fill = "steelblue",
    color = "black"
  ) +
  stat_bin(
    binwidth = 1,
    boundary = 0,
    geom = "text",
    aes(label = after_stat(ifelse(count > 0, count, ""))),
    vjust = -0.3,
    size = 3
  ) +
  labs(
    title = "Number of K Numbers",
    x = "Number of K Numbers",
    y = "Frequency"
  ) +
  theme_minimal()


# Variable: Reason length
p7 <- ggplot(recalls_model, aes(x = reason_length_chars)) +
  geom_histogram(
    bins = 30,
    fill = "steelblue",
    color = "black"
  ) +
  stat_bin(
    bins = 30,
    geom = "text",
    aes(label = after_stat(ifelse(count > 0, count, ""))),
    vjust = -0.3,
    size = 3
  ) +
  labs(
    title = "Reason Length",
    x = "Reason Length (Characters)",
    y = "Frequency"
  ) +
  theme_minimal()


# Display together
p5 | p6 | p7

#######################################
# Bar Graphs for "Event Observed", "Device Class", 
# "Medical Specialty", "Root Cause Description"

# Event observed
p1 <- ggplot(recalls_model, aes(x = factor(event_observed))) +
  geom_bar(fill = "steelblue", color = "black") +
  geom_text(
    stat = "count",
    aes(label = after_stat(count)),
    vjust = -0.3,
    size = 3
  ) +
  labs(
    title = "Event Observed",
    x = "Event Observed",
    y = "Frequency"
  ) +
  theme_minimal()


# Device class
p2 <- ggplot(recalls_model, aes(x = device_class)) +
  geom_bar(fill = "steelblue", color = "black") +
  geom_text(
    stat = "count",
    aes(label = after_stat(count)),
    vjust = -0.3,
    size = 3
  ) +
  labs(
    title = "Device Class",
    x = "Device Class",
    y = "Frequency"
  ) +
  theme_minimal()


# Medical specialty
p3 <- ggplot(
  recalls_model,
  aes(
    x = reorder(
      medical_specialty,
      medical_specialty,
      FUN = function(x) length(x)
    )
  )
) +
  geom_bar(fill = "steelblue", color = "black") +
  geom_text(
    stat = "count",
    aes(label = after_stat(count)),
    hjust = -0.2,
    size = 3
  ) +
  coord_flip() +
  labs(
    title = "Medical Specialty",
    x = "Medical Specialty",
    y = "Frequency"
  ) +
  theme_minimal()


# Root cause description
p4 <- ggplot(
  recalls_model,
  aes(
    x = reorder(
      root_cause_description,
      root_cause_description,
      FUN = function(x) length(x)
    )
  )
) +
  geom_bar(fill = "steelblue", color = "black") +
  geom_text(
    stat = "count",
    aes(label = after_stat(count)),
    hjust = -0.2,
    size = 3
  ) +
  coord_flip() +
  labs(
    title = "Root Cause Description",
    x = "Root Cause Description",
    y = "Frequency"
  ) +
  theme_minimal()


# Display all bar graphs in one output
(p1 | p2) /
p3 /
p4



# ------------------------------------------------------------
# 3. KAPLAN-MEIER CURVES (Overall & by Device Class)
# ------------------------------------------------------------
# S(t) = P(recall remains unresolved beyond time t)
# Hence, higher survival is worse from an operational perspective

# 3a. Overall recall resolution behavior
# ------------------------------------------------------------
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

summary(km_all)$table

# 3b. KAPLAN-MEIER BY DEVICE CLASS
# ------------------------------------------------------------

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
# 4. TRAIN / TEST SPLIT
# ------------------------------------------------------------
#The Following is an 80/20 Split
# with 323 training observations, 81 test observations

set.seed(1812)

n <- nrow(recalls_model)

train_index <- sample(
  1:n,
  size = round(0.80 * n)
)

train <- recalls_model[train_index, ]

test <- recalls_model[-train_index, ]


# removes unused factor levels
train <- droplevels(train)
test <- droplevels(test)


nrow(train)
nrow(test)


# Checking sample sizes for variables with collapsed categories
table(train$device_class, train$event_observed)
table(train$medical_specialty, train$event_observed)
table(train$root_cause_description, train$event_observed)

# Checking sample size & proportion of test/train split
table(train$event_observed)
table(test$event_observed)

prop.table(table(train$event_observed))
prop.table(table(test$event_observed))


# ------------------------------------------------------------
# 5. COX PROPORTIONAL HAZARDS MODEL & ASSUMPTION CHECK
# ------------------------------------------------------------

# the event defined is termination
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

# Proportional Hazards (PH) Assumption 
# Violation with Global p - value < 0.05
ph_test <- cox.zph(cox_model)
print(ph_test)

par(mfrow = c(3,2))
plot(ph_test)
par(mfrow = c(1,1))
####################################################################
# FINDING BEST MODEL FIT
# Log Logistic is best due to lower AIC

aft_weibull <- survreg(
  Surv(followup_days, event_observed) ~
    device_class +
    medical_specialty +
    root_cause_description +
    products_in_event +
    n_k_numbers +
    reason_length_chars,
  data = train,
  dist = "weibull"
)

aft_exponential <- survreg(
  Surv(followup_days, event_observed) ~
    device_class +
    medical_specialty +
    root_cause_description +
    products_in_event +
    n_k_numbers +
    reason_length_chars,
  data = train,
  dist = "exponential"
)

aft_lognormal <- survreg(
  Surv(followup_days, event_observed) ~
    device_class +
    medical_specialty +
    root_cause_description +
    products_in_event +
    n_k_numbers +
    reason_length_chars,
  data = train,
  dist = "lognormal"
)

aft_loglogistic <- survreg(
  Surv(followup_days, event_observed) ~
    device_class +
    medical_specialty +
    root_cause_description +
    products_in_event +
    n_k_numbers +
    reason_length_chars,
  data = train,
  dist = "loglogistic"
)


AIC(
  aft_weibull,
  aft_exponential,
  aft_lognormal,
  aft_loglogistic
)

summary(aft_loglogistic)
#######
# AFT Log Logistic Model Assumption Check
# Linearity of log follow up time is violated.
par(mfrow = c(1, 3))

plot(
  train$products_in_event,
  log(train$followup_days),
  xlab = "Products in Event",
  ylab = "Log Follow-up Time"
)

plot(
  train$n_k_numbers,
  log(train$followup_days),
  xlab = "Number of K Numbers",
  ylab = "Log Follow-up Time"
)

plot(
  train$reason_length_chars,
  log(train$followup_days),
  xlab = "Reason Length",
  ylab = "Log Follow-up Time"
)

par(mfrow = c(1, 1))

###############
# Spline ATF Model



aft_spline <- survreg(
  Surv(followup_days, event_observed) ~
    device_class +
    medical_specialty +
    root_cause_description +
    ns(products_in_event, df = 3) +
    ns(n_k_numbers, df = 3) +
    ns(reason_length_chars, df = 3),
  data = train,
  dist = "loglogistic"
)

summary(aft_spline)

# Tests to Determine best fit 
# aft log logistic model vs aft spline model
# 1. Akaike Information Criterion
# Compares both model to determine best fit.
# Lower AIC preferred
AIC(aft_loglogistic, aft_spline)

# 2. Likelihood ratio test
anova(aft_loglogistic, aft_spline)

# 3. Response Residual
# Difference between observed survival time and model predicted time
aft_resid <- residuals(aft_spline, type = "response")

plot(
  aft_resid,
  pch = 20,
  xlab = "Observation",
  ylab = "Response Residual",
  main = "AFT Model Residuals"
)

abline(h = 0, lty = 2)

# 4. Cox-Snell goodness-of-fit
linear_pred <- predict(aft_spline, type = "linear")

res_logistic <-
  (log(train$followup_days) - linear_pred) /
  aft_spline$scale

cox_snell_resid <- log(1 + exp(res_logistic))

fit_cs <- survfit(
  Surv(cox_snell_resid, train$event_observed) ~ 1
)

plot(
  fit_cs$time,
  fit_cs$cumhaz,
  type = "s",
  lwd = 2,
  xlab = "Cox-Snell Residual",
  ylab = "Estimated Cumulative Hazard",
  main = "Cox-Snell Residual Diagnostic"
)

abline(a = 0, b = 1, lty = 2, lwd = 2)


# 5. Multicollinearity
vif_model <- lm(
  log(followup_days) ~
    device_class +
    medical_specialty +
    root_cause_description +
    products_in_event +
    n_k_numbers +
    reason_length_chars,
  data = train
)

car::vif(vif_model)


############################################################
############################################################
############################################################
# To export to Power BI, change FALSE to TRUE
if (FALSE) {
# POWER BI EXPORTING CODE

#Exports all 404 observations and the 8 variables
write.csv(
  recalls_model,
  "recalls_powerbi.csv",
  row.names = FALSE
)
################
#Exports Kaplan Meier probabilities
# Overall curves
library(survival)

# Overall Kaplan-Meier model
km_overall <- survfit(
  Surv(followup_days, event_observed) ~ 1,
  data = recalls_model
)

# Extract survival estimates
km_overall_df <- data.frame(
  Time = c(0, km_overall$time),
  Survival = c(1, km_overall$surv),
  Lower_CI = c(1, km_overall$lower),
  Upper_CI = c(1, km_overall$upper),
  Group = "Overall"
)

# Export 1
write.csv(
  km_overall_df,
  "km_overall_powerbi.csv",
  row.names = FALSE
)
########################
# KM curves stratified by class
# Fit KM model by device class
km_class <- survfit(
  Surv(followup_days, event_observed) ~ device_class,
  data = recalls_model
)

# Extract estimates
km_class_df <- data.frame(
  Time = km_class$time,
  Survival = km_class$surv,
  Lower_CI = km_class$lower,
  Upper_CI = km_class$upper,
  Device_Class = rep(
    names(km_class$strata),
    times = as.integer(km_class$strata)
  )
)

# Clean group labels
km_class_df$Device_Class <- sub(
  "^device_class=",
  "",
  km_class_df$Device_Class
)

# Export #2 KM Stratified by Class
write.csv(
  km_class_df,
  "km_class_powerbi.csv",
  row.names = FALSE
)


#####################
# export #4 : AFT model comparison
model_comparison <- data.frame(
  Model = c(
    "Exponential AFT",
    "Weibull AFT",
    "Lognormal AFT",
    "Log-Logistic AFT",
    "Spline Log-Logistic AFT"
  ),
  AIC = c(
    AIC(aft_exponential),
    AIC(aft_weibull),
    AIC(aft_lognormal),
    AIC(aft_loglogistic),
    AIC(aft_spline)
  )
)

write.csv(
  model_comparison,
  "model_comparison_powerbi.csv",
  row.names = FALSE
)
########################
# export # significant categorical time ratios from spline aft model
# Extract coefficient summary
aft_coef <- as.data.frame(
  summary(aft_spline)$table
)

aft_coef$Predictor <- rownames(aft_coef)

# Exclude intercept, log(scale), and spline basis terms
aft_categorical <- aft_coef[
  !grepl(
    "Intercept|Log\\(scale\\)|^ns\\(",
    aft_coef$Predictor
  ),
]

# Construct export table
aft_tr_table <- data.frame(
  Predictor = aft_categorical$Predictor,
  Time_Ratio = exp(aft_categorical$Value),
  P_Value = aft_categorical$p
)

write.csv(
  aft_tr_table,
  "aft_time_ratios_powerbi.csv",
  row.names = FALSE
)
}
