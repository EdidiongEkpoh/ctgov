{% macro sponsor_key(name_col, class_col) -%}
    MD5(COALESCE(LOWER(TRIM({{ name_col }})), '') || '|' || COALESCE({{ class_col }}, ''))
{%- endmacro %}