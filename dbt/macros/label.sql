{% macro label(col) -%}
    INITCAP(REPLACE(LOWER({{ col }}), '_', ' '), '')
{%- endmacro %}