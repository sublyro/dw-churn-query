WITH all_active AS
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
), project AS ( 
	SELECT 
	 	p.account_id, 
	 	p.admin_account_id, 
	 	p.project_platforms, 
	 	p.project_status, 
	 	p.snippet_revision, 
	 	p.include_geotargeting, 
	 	p.include_jquery, 
	 	p.js_file_size --, 
	 	--p.usage_cumulative
	FROM all_active
	JOIN cust_gae_account p ON p.admin_account_id = all_active.account_number
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
		(all_active.end_date - e.created_gae) age_in_months_raw,
		((date_part ('days', (all_active.end_date - e.created_gae))) / 31) as age_in_months,
		p.admin_account_id admin_account_id
	FROM all_active 
	JOIN project p ON p.admin_account_id = all_active.account_number
	JOIN cust_gae_experiment e ON e.account_id = p.account_id
	WHERE e.status != 'Not started'
) SELECT a.account_id, 
	a.account_name, 
	a.user_name, 
	a.status, 
	a account_number, 
	a.start_date, 
	a.end_date, 
	a.vertical, 
	(SELECT COUNT(*) FROM experiment e WHERE e.account_id IN (SELECT p.account_id FROM project p WHERE p.admin_account_id = a.account_number)) as number_of_experiments,
	(SELECT COUNT(e.activation_mode) FROM experiment e WHERE e.admin_account_id = a.account_number AND activation_mode = 'conditional') as conditionally_activated_experiments,
	(SELECT COUNT(e.activation_mode) FROM experiment e WHERE e.admin_account_id = a.account_number AND activation_mode = 'manual') as manually_activated_experiments,
	(SELECT COUNT(experiment_type) FROM experiment e WHERE e.admin_account_id = a.account_number AND experiment_type = 'multivariate') as multivariate_experiments,
	(SELECT COUNT(experiment_type) FROM experiment e WHERE e.admin_account_id = a.account_number AND experiment_type = 'multipage') as multipage_experiments
FROM all_active a 
--LEFT JOIN dim_customer as cust ON cust.customer_id = a.account_number
--ORDER BY status, account_name, age