{
  python,
  dbt-bigquery,
  dbt-core,
  dbt-postgres,
  dbt-redshift,
  dbt-snowflake,
}:
let
  adapters = {
    inherit
      dbt-bigquery
      dbt-postgres
      dbt-redshift
      dbt-snowflake
      ;
  };
in
adapterFun:
(python.buildEnv.override {
  extraLibs = [ dbt-core ] ++ (adapterFun adapters);
  ignoreCollisions = true;
}).overrideAttrs
  { meta.mainProgram = dbt-core.meta.mainProgram; }
