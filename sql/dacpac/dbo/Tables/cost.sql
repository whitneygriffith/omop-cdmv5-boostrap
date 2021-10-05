CREATE TABLE [dbo].[cost] (
    [cost_id]                  INT          NOT NULL,
    [cost_event_id]            INT          NOT NULL,
    [cost_domain_id]           VARCHAR (20) NOT NULL,
    [cost_type_concept_id]     INT          NOT NULL,
    [currency_concept_id]      INT          NULL,
    [total_charge]             FLOAT (53)   NULL,
    [total_cost]               FLOAT (53)   NULL,
    [total_paid]               FLOAT (53)   NULL,
    [paid_by_payer]            FLOAT (53)   NULL,
    [paid_by_patient]          FLOAT (53)   NULL,
    [paid_patient_copay]       FLOAT (53)   NULL,
    [paid_patient_coinsurance] FLOAT (53)   NULL,
    [paid_patient_deductible]  FLOAT (53)   NULL,
    [paid_by_primary]          FLOAT (53)   NULL,
    [paid_ingredient_cost]     FLOAT (53)   NULL,
    [paid_dispensing_fee]      FLOAT (53)   NULL,
    [payer_plan_period_id]     INT          NULL,
    [amount_allowed]           FLOAT (53)   NULL,
    [revenue_code_concept_id]  INT          NULL,
    [reveue_code_source_value] VARCHAR (50) NULL,
    [drg_concept_id]           INT          NULL,
    [drg_source_value]         VARCHAR (3)  NULL,
    CONSTRAINT [xpk_visit_cost] PRIMARY KEY NONCLUSTERED ([cost_id] ASC)
);


GO

