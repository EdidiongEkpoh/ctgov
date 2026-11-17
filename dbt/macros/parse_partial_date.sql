{% macro parse_partial_date(col) -%}
    CASE    
        WHEN {{ col }} IS NULL THEN NULL
        WHEN length({{ col }}) = 10 THEN try_to_date({{ col }}, 'YYYY-MM-DD')
        WHEN LENGTH({{ col }}) = 7 THEN last_day(try_to_date({{ col }} || '-01', 'YYYY-MM-DD'))
        WHEN LENGTH({{ col }}) = 4 THEN last_day(try_to_date({{ col }} || '-01-01', 'YYYY-MM-DD'), 'year')
        ELSE NULL 
    END
{%- endmacro %}