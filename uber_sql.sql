CREATE DATABASE uber_db;
USE uber_db;
DROP DATABASE IF EXISTS uber_db;
CREATE DATABASE uber_db;
USE uber_db;
CREATE TABLE uber_requests (
    Request_id INT,
    Pickup_point VARCHAR(20),
    Driver_id INT NULL,
    Status VARCHAR(50),
    Request_timestamp TEXT,
    Time_slot VARCHAR(20),
    Drop_timestamp TEXT,
    Hour_of_day INT,
    Weekday VARCHAR(15)
);
-- Add new column for formatted request timestamp
ALTER TABLE uber_requests
ADD COLUMN formatted_request_time DATETIME;

-- Convert request timestamp
UPDATE uber_requests
SET formatted_request_time = STR_TO_DATE(Request_timestamp, '%d-%m-%Y %H:%i');

-- Add new column for formatted drop timestamp
ALTER TABLE uber_requests
ADD COLUMN formatted_drop_time DATETIME;

-- Convert drop timestamp, skipping null or blank entries
UPDATE uber_requests
SET formatted_drop_time = STR_TO_DATE(Drop_timestamp, '%d-%m-%Y %H:%i')
WHERE Drop_timestamp IS NOT NULL AND Drop_timestamp != '';

-- Requests per pickup point
SELECT Pickup_point, COUNT(*) AS total_requests
FROM uber_requests
GROUP BY Pickup_point;

-- Cancellations or No Cars by Time Slot
SELECT Time_slot, COUNT(*) AS issue_count
FROM uber_requests
WHERE Status IN ('Cancelled', 'No Cars Available')
GROUP BY Time_slot;

-- Peak failure hours
SELECT Hour_of_day, COUNT(*) AS failed_requests
FROM uber_requests
WHERE Status IN ('Cancelled', 'No Cars Available')
GROUP BY Hour_of_day
ORDER BY failed_requests DESC;
-- This helps compare actual ride times and see where drivers might be slow or fast.
ALTER TABLE uber_requests
ADD COLUMN trip_duration_minutes INT;

UPDATE uber_requests
SET trip_duration_minutes = TIMESTAMPDIFF(MINUTE, formatted_request_time, formatted_drop_time)
WHERE formatted_request_time IS NOT NULL AND formatted_drop_time IS NOT NULL;

-- Mark Weekend vs Weekday
ALTER TABLE uber_requests
ADD COLUMN is_weekend BOOLEAN;

UPDATE uber_requests
SET is_weekend = CASE 
    WHEN Weekday IN ('Saturday', 'Sunday') THEN TRUE
    ELSE FALSE
END;

 -- Flag Demand-Supply Gap Cases Mark trips that were cancelled or had no cars available:
ALTER TABLE uber_requests
ADD COLUMN demand_supply_issue BOOLEAN;

UPDATE uber_requests
SET demand_supply_issue = CASE 
    WHEN Status IN ('Cancelled', 'No Cars Available') THEN TRUE
    ELSE FALSE
END;

-- Categorize Time into Period Buckets (Optional if Time_slot isn’t accurate) If your Time_slot is messy or missing, create it from Hour_of_day:
ALTER TABLE uber_requests
ADD COLUMN derived_time_slot VARCHAR(20);

UPDATE uber_requests
SET derived_time_slot = CASE
    WHEN Hour_of_day BETWEEN 4 AND 7 THEN 'Early Morning'
    WHEN Hour_of_day BETWEEN 8 AND 11 THEN 'Morning'
    WHEN Hour_of_day BETWEEN 12 AND 16 THEN 'Day'
    WHEN Hour_of_day BETWEEN 17 AND 20 THEN 'Evening'
    WHEN Hour_of_day BETWEEN 21 AND 23 THEN 'Night'
    ELSE 'Unavailable'
END;

-- Time slots with most demand-supply issues
SELECT Time_slot, COUNT(*) AS issue_count
FROM uber_requests
WHERE demand_supply_issue = TRUE
GROUP BY Time_slot
ORDER BY issue_count DESC;



-- Pickup point performance comparison
SELECT Pickup_point,
       COUNT(*) AS total_requests,
       SUM(CASE WHEN demand_supply_issue = TRUE THEN 1 ELSE 0 END) AS failed_requests,
       ROUND(SUM(CASE WHEN demand_supply_issue = TRUE THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS failure_rate_percent
FROM uber_requests
GROUP BY Pickup_point;

-- Average Trip Duration by Time Slot
SELECT Time_slot,
       AVG(trip_duration_minutes) AS avg_duration
FROM uber_requests
WHERE trip_duration_minutes IS NOT NULL
GROUP BY Time_slot
ORDER BY avg_duration DESC;


--  Demand-Supply Issues by Time Slot and Pickup Point Insight: This tells us where and when Uber faces the highest failure in fulfilling ride requests. 
SELECT 
    Pickup_point,
    Time_slot,
    COUNT(*) AS total_requests,
    SUM(CASE WHEN demand_supply_issue = TRUE THEN 1 ELSE 0 END) AS issue_count,
    ROUND(SUM(CASE WHEN demand_supply_issue = TRUE THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS issue_rate_percent
FROM uber_requests
GROUP BY Pickup_point, Time_slot
ORDER BY issue_rate_percent DESC;


-- cancellation/No Cars Rate by Hour of Day Pinpoints the exact hours when Uber faces high cancellations or car unavailability.
SELECT 
    Hour_of_day,
    COUNT(*) AS total_requests,
    SUM(CASE WHEN demand_supply_issue = TRUE THEN 1 ELSE 0 END) AS issue_count,
    ROUND(SUM(CASE WHEN demand_supply_issue = TRUE THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS issue_rate_percent
FROM uber_requests
GROUP BY Hour_of_day
ORDER BY Hour_of_day;

-- Cancellation/No Cars Rate by Weekday
SELECT 
    Weekday,
    COUNT(*) AS total_requests,
    SUM(CASE WHEN demand_supply_issue = TRUE THEN 1 ELSE 0 END) AS issue_count,
    ROUND(SUM(CASE WHEN demand_supply_issue = TRUE THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS issue_rate_percent
FROM uber_requests
GROUP BY Weekday
ORDER BY FIELD(Weekday, 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday');


-- Average Trip Duration by Time Slot
SELECT 
    Time_slot,
    COUNT(*) AS completed_trips,
    AVG(trip_duration_minutes) AS avg_trip_duration
FROM uber_requests
WHERE Status = 'Trip Completed' AND trip_duration_minutes IS NOT NULL
GROUP BY Time_slot
ORDER BY avg_trip_duration DESC;














