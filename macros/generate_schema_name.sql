{% macro generate_schema_name(custom_schema_name, node) -%}
  {%- set default_schema = target.schema -%}

  {%- if custom_schema_name is none -%}
    {# If no custom schema is specified, use the default target schema #}
    {{ default_schema }}
  {%- else -%}
    {# If a custom schema is specified, use ONLY that custom schema name #}
    {{ custom_schema_name | trim }}
  {%- endif -%}

{%- endmacro %}