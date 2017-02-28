SELECT * FROM (
    SELECT category, description, sum(amount_in_eur) AS total
    FROM records
    WHERE timestamp
    BETWEEN '2017-02-01'::timestamp AND '2017-03-01'::timestamp
    GROUP BY category, description
    ORDER BY total ASC
) AS results
WHERE abs(total) > 15;
