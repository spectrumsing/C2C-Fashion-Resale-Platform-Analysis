-- Load data

CREATE TABLE
    accounts (
        account_id BIGINT PRIMARY KEY,
        user_type TEXT,
        country TEXT,
        lang TEXT,
        followers INT,
        follows INT,
        liked INT,
        listed INT,
        sold INT,
        pass_rate FLOAT,
        wished INT,
        bought INT,
        gender TEXT,
        gender_id INT,
        title TEXT,
        app BOOLEAN,
        android BOOLEAN,
        ios BOOLEAN,
        pic BOOLEAN,
        days_since_last_login INT,
        seniority FLOAT,
        seniority_month FLOAT,
        seniority_yrs FLOAT,
        country_ISO TEXT
    );

COPY accounts
FROM
    'C:\users.6M0xxK.2020.public.csv' (FORMAT CSV, DELIMITER ',', HEADER);

CREATE TABLE
    geo_lookup (
      name TEXT PRIMARY KEY,
      ISO TEXT,
      region TEXT,
      subregion TEXT
    );

COPY geo_lookup
FROM
    'C:\geo_lookup.csv' (FORMAT CSV, DELIMITER ',', HEADER, QUOTE '"');

CREATE INDEX idx_accounts_id ON accounts(account_id);



-- User retention


-- How many active users are there?
SELECT
    COUNT(*) AS users
FROM accounts
WHERE
    bought + sold + listed + liked + wished > 0;


-- What is the composition of the user base by engagement type?
WITH engagement AS (
    SELECT
        CASE
            WHEN bought + sold + listed = 1 THEN 'one-time'
            WHEN bought + sold + listed > 1 THEN 'return'
            WHEN liked + wished > 0 THEN 'prospective'
            ELSE 'inactive' 
        END AS segment
    FROM accounts
),

segment_count AS (
	SELECT 
	    segment,
	    COUNT(*) AS users,
	    ROUND(COUNT(*) / SUM(COUNT(*)) OVER ()::NUMERIC * 100, 1) AS pct_users
	FROM engagement
	GROUP BY segment
)

SELECT * FROM segment_count;


-- How many users logged in within the past year?

SELECT 
    COUNT(*) AS users,
    ROUND(COUNT(*) / (SELECT COUNT(*) FROM accounts)::NUMERIC * 100, 1) AS pct_users
FROM accounts
WHERE
    days_since_last_login <= 365;


-- Are inactive users still visiting the platform without engaging listings, or have they dropped out completely?

WITH retained AS (
	SELECT
		bought + sold + listed + liked + wished > 0 AS is_active,
		CASE 
			WHEN days_since_last_login <= 365 THEN 1
			ELSE NULL
		END AS login
    FROM accounts
),
percent_retained AS (
	SELECT 
		is_active,
		ROUND(SUM(login) / SUM(COUNT(*)) OVER(PARTITION BY is_active)::NUMERIC * 100, 1) AS pct
	FROM retained 
	GROUP BY is_active
) 
SELECT * FROM percent_retained;



-- Buyer behavior


-- How many items have buyers purchased on average?

WITH buyer AS (
	SELECT 
		bought,
	    (seniority - days_since_last_login) / 365.25 AS lifespan_yr
	FROM accounts
	WHERE 
		bought > 0
),
buyer_avg AS (
	SELECT 
		COUNT(*) AS users,
		ROUND(AVG(lifespan_yr)::NUMERIC, 2) AS avg_lifespan_yr,
		ROUND(AVG(bought)::NUMERIC, 2) AS avg_purchased,
		ROUND(AVG(bought / lifespan_yr::NUMERIC), 2) AS purchased_per_yr
	FROM buyer
)
SELECT * FROM buyer_avg;


WITH loyalty AS (
    SELECT 
        CASE 
            WHEN bought = 1 THEN 'one_time'
            ELSE 'repeat' 
        END AS segment
    FROM accounts
    WHERE
        bought > 0
),
distribution AS (    
    SELECT
        segment,
        ROUND(COUNT(*) / SUM(COUNT(*)) OVER()::NUMERIC * 100, 1) AS pct
    FROM loyalty
    GROUP BY segment
)
SELECT * 
FROM distribution
ORDER BY pct DESC;


-- Do the number of accounts followed and items liked have a meaningful relationship with actual purchases?

SELECT
    ROUND(CORR(follows, bought)::NUMERIC, 2) AS follow_corr,
    ROUND(CORR(liked, bought)::NUMERIC, 2) AS liked_corr,
    ROUND(CORR(wished, bought)::NUMERIC, 2) AS wishlist_corr
FROM accounts
WHERE
    bought > 0;



-- Seller behavior


-- setup seller view

CREATE VIEW sellers AS (
	SELECT 	
        followers,
		sold,
		(seniority - days_since_last_login) / 365.25 AS lifespan_yr,
		listed + sold AS listing,
        sold / (listed + sold)::NUMERIC AS sell_through_rate,
		pass_rate,
		country_iso
	FROM accounts 
	WHERE 
		sold > 0
		

-- How many items have sellers sold? How is the pass rate and sell-through rate?

SELECT 	
	COUNT(*) AS users,
    ROUND(AVG(lifespan_yr)::NUMERIC, 2) AS avg_lifespan_yr,
	ROUND(AVG(sold)::NUMERIC, 2) AS avg_sold,
	ROUND(AVG(listing)::NUMERIC, 2) AS avg_listing,
    ROUND(SUM(ROUND((sold * pass_rate)::NUMERIC / 100)) / SUM(listing)::NUMERIC * 100, 1) AS platform_pass_rate,
	ROUND(AVG(pass_rate)::NUMERIC, 1) AS avg_seller_pass_rate,
    ROUND(SUM(sold) / SUM(listing)::NUMERIC * 100, 1) AS platform_sell_through_rate,
	ROUND(AVG(sell_through_rate)::NUMERIC * 100, 1) AS avg_sell_through_rate
FROM sellers;


WITH loyalty AS (
    SELECT 
        CASE 
            WHEN sold = 1 THEN 'one_time'
            ELSE 'return' 
        END AS segment
    FROM sellers
),
distribution AS (    
    SELECT
        segment,
        ROUND(COUNT(*) / SUM(COUNT(*)) OVER()::NUMERIC * 100, 1) AS pct
    FROM loyalty
    GROUP BY segment
)
SELECT * 
FROM distribution
ORDER BY pct DESC;


-- How many sellers failed to pass their first vetting process?

SELECT
    'min' AS scenario,
    COUNT(*) AS users,
    ROUND(COUNT(*) / (SELECT COUNT(*) FROM sellers)::NUMERIC * 100, 1) AS pct
FROM sellers
WHERE
    pass_rate = 0
UNION ALL 
SELECT
    'max' AS scenario,
    COUNT(*) AS users,
    ROUND(COUNT(*) / (SELECT COUNT(*) FROM sellers)::NUMERIC * 100, 1) AS pct
FROM sellers
WHERE 
    pass_rate < 100
    

    SELECT
    ROUND(SUM(CASE WHEN pass_rate = 0 THEN 1 ELSE 0 END) /  COUNT(*)::NUMERIC * 100, 1) AS pct0_pass_rate
FROM sellers
WHERE 
    sold > 1;

    
-- Do the number of followers have a meaningful relationship with actual sales?

SELECT 
	ROUND(CORR(followers, sold)::NUMERIC, 2) AS sold_corr,
    ROUND(CORR(followers, listing)::NUMERIC, 2) AS listing_corr,
    ROUND(CORR(followers, sell_through_rate)::NUMERIC, 2) AS sell_through_corr
FROM sellers;


-- Do the number of listings have a relationship with actual sales?

SELECT 
    ROUND(CORR(listing, sold)::NUMERIC, 2) AS sold_corr,
    ROUND(CORR(listing, sell_through_rate)::NUMERIC, 2) AS sell_through_corr
FROM sellers;


-- Does having a trusted seller badge make a difference?

SELECT 
	ROUND(CORR(followers, sold)::NUMERIC, 2) AS sold_corr,
    ROUND(CORR(followers, listing)::NUMERIC, 2) AS listing_corr,
    ROUND(CORR(followers, sell_through_rate)::NUMERIC, 2) AS sell_through_rate_corr
FROM sellers
WHERE 
    sold >= 2
    AND pass_rate >= 80;


SELECT 
    pass_rate >= 80 AS is_trusted,
    COUNT(*) AS users,
    ROUND(SUM(sold) / SUM(listing)::NUMERIC * 100, 1) AS platform_sell_through_rate,
    ROUND(AVG(sell_through_rate)::NUMERIC * 100, 1) AS avg_sell_through_rate,
    ROUND(STDDEV_POP(sell_through_rate)::NUMERIC * 100, 1) AS std_dev
FROM sellers
WHERE
    sold >= 2
GROUP BY is_trusted;


-- Seller statistics by country, sorted by number of sellers

SELECT 
	geo_lookup.name AS country,
	COUNT(*) AS sellers,
	SUM(sold) AS sold,
	ROUND(AVG(sold)::NUMERIC, 2) AS avg_sold,
	ROUND(AVG(pass_rate)::NUMERIC, 1) AS avg_pass_rate,
	ROUND(AVG(sold / (listed + sold))::NUMERIC * 100, 1) AS avg_sell_through_rate
FROM accounts
LEFT JOIN geo_lookup
	ON upper(accounts.country_iso) = geo_lookup.iso   
WHERE 
	accounts.sold > 0
GROUP BY country
ORDER BY sellers DESC;



-- App usage


-- Is there a discernible difference in transaction activity between app and non-app users?

SELECT 
    app AS has_app,
    COUNT(*) AS users,
    ROUND(COUNT(*) / SUM(COUNT(*)) OVER()::NUMERIC * 100, 1) AS share_users,
    SUM(bought) AS purchased,
    ROUND(SUM(bought) / SUM(SUM(bought)) OVER()::NUMERIC * 100, 1) AS share_purchased,
    ROUND(AVG(bought)::NUMERIC , 2) AS purchased_per_user, 
    SUM(sold) AS sold,
    ROUND(SUM(sold) / SUM(SUM(sold)) OVER()::NUMERIC * 100, 1) AS share_sold,
    ROUND(AVG(sold)::NUMERIC , 2) AS sold_per_user 
FROM accounts
WHERE 
    bought + sold + listed + liked + wished > 0
GROUP BY has_app; 


-- Do iOS and Android users differ significantly in transaction activity?

SELECT 
    CASE 
        WHEN ios IS TRUE THEN 'ios'
        ELSE 'android'
    END AS OS,
    COUNT(*) AS users,
    ROUND(COUNT(*) / SUM(COUNT(*)) OVER()::NUMERIC * 100, 1) AS share_users,
    SUM(bought) AS purchased,
    ROUND(SUM(bought) / SUM(SUM(bought)) OVER()::NUMERIC * 100, 1) AS share_purchased,
    ROUND(AVG(bought)::NUMERIC , 2) AS bought_per_user, 
    SUM(sold) AS sold,
    ROUND(SUM(sold) / SUM(SUM(sold)) OVER()::NUMERIC * 100, 1) AS share_sold,
    ROUND(AVG(sold)::NUMERIC , 2) AS sold_per_user 
FROM accounts
WHERE 
    bought + sold + listed + liked + wished > 0 
    AND app IS TRUE
GROUP BY OS; 



-- Geographic


-- Number of total and active users by country, sorted by total users

SELECT 
	geo_lookup.name AS country,
	COUNT(*) AS total_users,
	COUNT(
		CASE 
	    	WHEN bought + sold + listed + liked + wished > 0 THEN 1
	    	ELSE NULL
	    END
	) AS active_users
FROM accounts
LEFT JOIN geo_lookup
	ON upper(accounts.country_iso) = geo_lookup.iso
GROUP BY country
ORDER BY total_users DESC;


-- Total and per buyer purchase of each country

SELECT
    geo_lookup.name AS country,
    SUM(bought) AS purchased,
    COUNT(*) AS users,
    ROUND(AVG(bought)::NUMERIC, 2) AS avg_purchased,
    ROUND(COUNT(*) / SUM(COUNT(*)) OVER()::NUMERIC * 100, 1) AS share_buyers
FROM accounts
LEFT JOIN geo_lookup
	ON upper(accounts.country_iso) = geo_lookup.iso
WHERE bought > 0
GROUP BY country
ORDER BY purchased DESC;   
--ORDER BY purchased_per_buyer DESC;


-- Total and per seller sales of each country

SELECT
    geo_lookup.name AS country,
    SUM(sold) AS sold,
    COUNT(*) AS users,
    ROUND(AVG(sold)::NUMERIC, 2) AS sold_per_seller,
    ROUND(AVG(sell_through_rate) * 100, 1) AS avg_sell_through_rate
FROM sellers
LEFT JOIN geo_lookup
	ON upper(sellers.country_iso) = geo_lookup.iso
GROUP BY country
ORDER BY sold DESC;


-- Are there any subregions with a high sales volume and low pass rate?

SELECT 
	geo_lookup.subregion AS subregion,
	SUM(sold) AS sold,
	ROUND(AVG(sold)::NUMERIC, 2) AS avg_sold,
	ROUND(AVG(pass_rate)::NUMERIC, 1) AS avg_pass_rate
FROM 
	sellers
LEFT JOIN geo_lookup
	ON UPPER(sellers.country_iso) = geo_lookup.iso   
GROUP BY subregion
ORDER BY avg_pass_rate;