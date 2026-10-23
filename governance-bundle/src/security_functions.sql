-- Creates the functions the ABAC policies call, in <catalog>.security.
-- :catalog is a job parameter (sales_dev, marketing_dev, ...). CREATE OR REPLACE
-- makes every run safe to repeat, and restores a function edited by hand.

-- Column mask: first argument and return type match the masked column. Who sees
-- the real value is decided by the policy (to_principals / except_principals),
-- not here.
CREATE OR REPLACE FUNCTION IDENTIFIER(:catalog || '.security.mask_pii')(value STRING)
RETURNS STRING
COMMENT 'Redacts a PII value. Applied by the mask_pii_columns policy to columns tagged sensitivity=pii.'
RETURN CASE WHEN value IS NULL THEN NULL ELSE '***REDACTED***' END;

-- Row filter: keeps a row only when the caller belongs to the account group for
-- that row's region, for example grp-region-eu. EXAMPLE rule: replace it with
-- your real residency or segmentation rule before enabling the policy.
CREATE OR REPLACE FUNCTION IDENTIFIER(:catalog || '.security.filter_region')(region STRING)
RETURNS BOOLEAN
COMMENT 'Row filter by region group membership. Applied by the filter_region_rows policy to columns tagged row_scope=region.'
RETURN is_account_group_member(CONCAT('grp-region-', LOWER(region)));
