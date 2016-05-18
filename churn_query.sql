WITH emea_active AS
(
    SELECT
        DISTINCT sfac.account_id,
        sfac.account_name,
        own.user_name,
        'active' status,
        CASE WHEN sfac.account_number IS NOT NULL THEN sfac.account_number ELSE sfac.recurly_account_code END as account_number,
        (SELECT op.subscription_start_date 
        FROM   cust_sf_opportunity op 
        WHERE  op.account_id = sfac.account_id 
               AND op.stage_name = 'Closed Won' 
               AND ( op.bookings_type = 'Vertical Expansion' 
                      OR op.opportunity_type = 'New' ) 
        ORDER  BY op.subscription_start_date 
        LIMIT  1) as start_date, 
        now() as end_date,
        ind.industry_name vertical, ROUND(sfac.monthly_recurring_revenue) mrr
    FROM cust_sf_account sfac 
    LEFT JOIN cust_sf_user own ON sfac.owner_id = own.user_id 
    LEFT JOIN cust_sf_account_team_member tm ON tm.account_id = sfac.account_id 
    LEFT JOIN cust_sf_user csm ON csm.user_id = tm.user_id
    LEFT JOIN cust_sf_subscription sfs on sfac.account_id=sfs.account_id
    LEFT JOIN dim_customer dc on sfs.account_code=dc.customer_id
    LEFT JOIN dim_subscription_plan dsp on dc.current_subscription_id=dsp.subscription_id
    LEFT JOIN dim_industry ind ON ind.industry_id = sfac.industry_id 
    WHERE
        (
            (
                dsp.subscription_id in (14,5,9,7) AND 
                dc.current_subscription_state_id in (1,4)
            ) 
            OR  
            ( 
                sfs.subscription_id is null AND 
                recurly_subscriber='Y'
            )
        )
        AND
        (
            sfac.recurly_plan_code IS NULL
            OR sfac.recurly_plan_code = 'null'
            OR sfac.recurly_plan_code LIKE '%\_d%_m%'
            OR sfac.recurly_plan_code LIKE '%nterprise%'
            OR sfac.recurly_plan_code LIKE '%latinum%'
        )
        AND
        (
            sfac.customer_type IS NULL
            OR
            (
                sfac.customer_type NOT LIKE '%nternal%'
                AND sfac.customer_type NOT LIKE '%artner%'
            )
        )
        AND
        (
            (
                (
                    own.user_role_id IN
                    (
                        '00EC0000001g6U8MAI',
                        '00EC0000001g6U9MAI',
                        '00EC0000001g6UAMAY',
                        '00EC0000001gPIsMAM'
                    )
                    OR csm.user_role_id IN
                    (
                        '00EC0000001g6U8MAI',
                        '00EC0000001g6U9MAI',
                        '00EC0000001g6UAMAY',
                        '00EC0000001gPIsMAM'
                    )
                )
                AND tm.team_member_role = 'Customer Success Manager'
            )
            OR
            (
                own.user_id='005C0000008RbpjIAC'
                AND sfac.region ='EMEA'
            )
        )
), emea_churn AS
(
    SELECT
        DISTINCT sfac.account_id,
        sfac.account_name,
        own.user_name,
        'churn' status,
        CASE WHEN sfac.account_number IS NOT NULL THEN sfac.account_number ELSE sfac.recurly_account_code END as account_number,
        (SELECT op.subscription_start_date 
        FROM   cust_sf_opportunity op 
        WHERE  op.account_id = sfac.account_id 
               AND op.stage_name = 'Closed Won' 
               AND ( op.bookings_type = 'Vertical Expansion' 
                      OR op.opportunity_type = 'New' ) 
        ORDER  BY op.subscription_start_date 
        LIMIT  1) as start_date, 
       (SELECT op.close_date 
        FROM   cust_sf_opportunity op 
        WHERE  op.account_id = sfac.account_id 
               AND (op.stage_name = 'Cancelled' OR ( op.stage_name = 'Closed Lost' AND op.opportunity_type like '%enewal%' AND op.lost_reason != 'Duplicate' AND op.churn_category != 'Gap churn')) 
        ORDER  BY op.close_date DESC 
        LIMIT  1) as end_date,
        ind.industry_name vertical, ROUND(sfac.monthly_recurring_revenue) mrr
    FROM cust_sf_account sfac 
    LEFT JOIN cust_sf_user own ON sfac.owner_id = own.user_id 
    LEFT JOIN cust_sf_account_team_member tm ON tm.account_id = sfac.account_id 
    LEFT JOIN cust_sf_user csm ON csm.user_id = tm.user_id
    LEFT JOIN cust_sf_subscription sfs on sfac.account_id=sfs.account_id
    LEFT JOIN dim_customer dc on sfs.account_code=dc.customer_id
    LEFT JOIN dim_subscription_plan dsp on dc.current_subscription_id=dsp.subscription_id
    LEFT JOIN dim_industry ind ON ind.industry_id = sfac.industry_id 
    WHERE
        (
            (
                dsp.subscription_id in (14,5,9,7) AND 
                dc.current_subscription_state_id in (2)
            ) 
            /*OR  
            ( 
                sfs.subscription_id is null 
                AND sfac.region = 'EMEA'
                recurly_subscriber='Y'
            )*/
        )
        AND
        (
            sfac.recurly_plan_code IS NULL
            OR sfac.recurly_plan_code = 'null'
            OR sfac.recurly_plan_code LIKE '%\_d%_m%'
            OR sfac.recurly_plan_code LIKE '%nterprise%'
            OR sfac.recurly_plan_code LIKE '%latinum%'
        )
        AND
        (
            sfac.customer_type IS NULL
            OR
            (
                sfac.customer_type NOT LIKE '%nternal%'
                AND sfac.customer_type NOT LIKE '%artner%'
            )
        )
        AND
        (
            (
                (
                    own.user_role_id IN
                    (
                        '00EC0000001g6U8MAI',
                        '00EC0000001g6U9MAI',
                        '00EC0000001g6UAMAY',
                        '00EC0000001gPIsMAM'
                    )
                    OR csm.user_role_id IN
                    (
                        '00EC0000001g6U8MAI',
                        '00EC0000001g6U9MAI',
                        '00EC0000001g6UAMAY',
                        '00EC0000001gPIsMAM'
                    )
                )
                AND tm.team_member_role = 'Customer Success Manager'
            )
            OR
            (
                own.user_id='005C0000008RbpjIAC'
                AND sfac.region ='EMEA'
            )
        )
), emea AS (SELECT * from emea_active UNION SELECT * from emea_churn
), project AS ( 
	SELECT 
	 	p.account_id, 
	 	p.admin_account_id, 
	 	p.project_platforms, 
	 	p.project_status, 
	 	p.snippet_revision, 
	 	p.include_geotargeting, 
	 	p.include_jquery, 
	 	p.js_file_size 
	 	--p.usage_cumulative
	FROM emea
	JOIN cust_gae_account p ON p.admin_account_id = emea.account_number
	WHERE p.project_platforms = 'web'
), experiment AS (
	SELECT 
		e.experiment_id, 
		e.account_id, 
		e.condition_id, 
		e.audiences, 
		e.activation_mode, 
		e.editor_compatibility_mode, 
		e.percentage_included, 
		e.status, 
		e.experiment_type, 
		e.created_gae, 
		(emea.end_date - e.created_gae) age_in_months_raw,
		((date_part ('days', (emea.end_date - e.created_gae))) / 31) as age_in_months,
		p.admin_account_id admin_account_id
	FROM emea 
	JOIN project p ON p.admin_account_id = emea.account_number
	JOIN cust_gae_experiment e ON e.account_id = p.account_id
	WHERE e.status != 'Not started'
), res AS (SELECT emea.account_id, 
	emea.account_name, 
	emea.user_name, 
	emea.status, 
	emea account_number, 
	emea.start_date, 
	emea.end_date, 
	emea.vertical, 
	CASE WHEN emea.mrr > 10000 THEN '11000' ELSE to_char(emea.mrr, '999999')  END as mrr,
	(SELECT date_part ('year', f) * 12 + date_part ('month', f) FROM age (end_date, start_date) f) as age,
	(SELECT COUNT(*) FROM project p WHERE p.admin_account_id = emea.account_number) as number_of_web_projects,
	1, -- (SELECT COUNT(*) FROM project p WHERE p.admin_account_id = emea.account_number AND p.project_status = 'Active') as number_of_active_web_projects,
	(SELECT MAX(snippet_revision) FROM project p WHERE p.admin_account_id = emea.account_number AND p.project_platforms = 'web') as max_snippet_revisions,
	(SELECT MAX(js_file_size) FROM project p WHERE p.admin_account_id = emea.account_number AND p.project_platforms = 'web') as max_js_size,
	1, -- (SELECT SUM(usage_cumulative) FROM project p WHERE p.admin_account_id = emea.account_number AND p.project_platforms = 'web') as usage_cumulative,
	(SELECT COUNT(*) FROM experiment e WHERE e.account_id IN (SELECT p.account_id FROM project p WHERE p.admin_account_id = emea.account_number)) as number_of_experiments,
	CASE WHEN (SELECT date_part ('year', f) * 12 + date_part ('month', f) FROM age (end_date, start_date) f) != 0 
		THEN ROUND((SELECT COUNT(*) FROM experiment e WHERE e.account_id IN (SELECT p.account_id FROM project p WHERE p.admin_account_id = emea.account_number)) / (SELECT date_part ('year', f) * 12 + date_part ('month', f) FROM age (end_date, start_date) f)) 
		ELSE 0 
		END 
	AS average_number_of_experiments_per_month,
	(SELECT COUNT(e.status) FROM experiment e WHERE e.admin_account_id = emea.account_number AND status = 'Running') as number_of_active_experiments,
	(SELECT COUNT(e.activation_mode) FROM experiment e WHERE e.admin_account_id = emea.account_number AND activation_mode = 'conditional') as conditionally_activated_experiments,
	(SELECT COUNT(e.activation_mode) FROM experiment e WHERE e.admin_account_id = emea.account_number AND activation_mode = 'manual') as manually_activated_experiments,
	(SELECT COUNT(experiment_type) FROM experiment e WHERE e.admin_account_id = emea.account_number AND experiment_type = 'multivariate') as multivariate_experiments,
	(SELECT COUNT(experiment_type) FROM experiment e WHERE e.admin_account_id = emea.account_number AND experiment_type = 'multipage') as multipage_experiments,
	(SELECT COUNT(e.experiment_id) FROM experiment e WHERE e.admin_account_id = emea.account_number AND age_in_months <= 1 AND age_in_months > 0) as number_of_active_experiments_1,
	(SELECT COUNT(e.experiment_id) FROM experiment e WHERE e.admin_account_id = emea.account_number AND age_in_months <= 2 AND age_in_months > 1) as number_of_active_experiments_2,
	(SELECT COUNT(e.experiment_id) FROM experiment e WHERE e.admin_account_id = emea.account_number AND age_in_months <= 3 AND age_in_months > 2) as number_of_active_experiments_3,
	(SELECT COUNT(e.experiment_id) FROM experiment e WHERE e.admin_account_id = emea.account_number AND age_in_months <= 4 AND age_in_months > 3) as number_of_active_experiments_4,
	(SELECT COUNT(e.experiment_id) FROM experiment e WHERE e.admin_account_id = emea.account_number AND age_in_months <= 5 AND age_in_months > 4) as number_of_active_experiments_5,
	(SELECT COUNT(e.experiment_id) FROM experiment e WHERE e.admin_account_id = emea.account_number AND age_in_months <= 6 AND age_in_months > 5) as number_of_active_experiments_6,
	1
FROM emea 
LEFT JOIN dim_customer as cust ON cust.customer_id = emea.account_number
ORDER BY status, account_name, age) 
--SELECT * from experiment
-- SELECT * from res
SELECT account_id, 
	account_name, 
	user_name, 
	status, 
	account_number, 
	start_date, 
	end_date, 
	vertical, 
	mrr,
	age,
	CASE WHEN number_of_web_projects > 20 THEN 21 ELSE number_of_web_projects END as number_of_web_projects,
	1, --number_of_active_web_projects,
	max_snippet_revisions,
	max_js_size,
	1, --usage_cumulative,
	number_of_experiments,
	CASE WHEN average_number_of_experiments_per_month > 40 THEN 41 ELSE average_number_of_experiments_per_month END as average_number_of_experiments_per_month,
	number_of_active_experiments,
	conditionally_activated_experiments,
	manually_activated_experiments,
	multivariate_experiments,
	multipage_experiments,
	CASE WHEN number_of_active_experiments_1 > 20 THEN 21 ELSE number_of_active_experiments_1 END as number_of_active_experiments_1,
	CASE WHEN number_of_active_experiments_2 > 20 THEN 21 ELSE number_of_active_experiments_2 END as number_of_active_experiments_2,
	CASE WHEN number_of_active_experiments_3 > 20 THEN 21 ELSE number_of_active_experiments_3 END as number_of_active_experiments_3,
	CASE WHEN number_of_active_experiments_4 > 20 THEN 21 ELSE number_of_active_experiments_4 END as number_of_active_experiments_4,
	CASE WHEN number_of_active_experiments_5 > 20 THEN 21 ELSE number_of_active_experiments_5 END as number_of_active_experiments_5,
	CASE WHEN number_of_active_experiments_6 > 20 THEN 21 ELSE number_of_active_experiments_6 END as number_of_active_experiments_6
FROM res