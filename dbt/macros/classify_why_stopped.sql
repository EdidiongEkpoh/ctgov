{% macro classify_why_stopped(col) -%}
    {%- set t = "lower(trim(" ~ col ~ "))" -%}
    case
        when {{ col }} is null or {{ t }} = ''                                   then 'unspecified'
        when regexp_like({{ t }}, '.*(safety|adverse|toxicit|side effect|death).*')      then 'safety'
        when regexp_like({{ t }}, '.*(futil|efficacy|lack of benefit|interim analys).*') then 'efficacy_futility'
        when regexp_like({{ t }}, '.*(covid|coronavirus|pandemic|sars-cov).*')           then 'covid_19'
        when regexp_like({{ t }}, '.*(accru|enrol|recruit|participant|patients? avail).*') then 'enrollment'
        when regexp_like({{ t }}, '.*(fund|financ|budget|business|commercial|strateg).*') then 'funding_business'
        when regexp_like({{ t }}, '.*(sponsor|company decision|portfolio|priorit).*')    then 'sponsor_decision'
        when regexp_like({{ t }}, '.*(\\bpi\\b|investigator (left|leaving|moved|retire)).*') then 'pi_left'
        else 'other'
    end
{%- endmacro %}