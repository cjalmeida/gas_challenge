drop table if exists crude_oil_and_petroleum;
drop table if exists total_gasoline;
drop table if exists crude_oil_future_contract;
drop table if exists us_regular_conventional_gasoline_price;
drop table if exists us_field_production_of_curde_oil;
drop table if exists total_gasoline_by_prime_supplier;

create table crude_oil_and_petroleum (
	date DATE,
	weekly_ending_stock BIGINT
);


create table total_gasoline (
	date DATE,
	weekly_ending_stock BIGINT
);

create table crude_oil_future_contract (
	date DATE,
	dollars_per_barrel FLOAT
);

create table us_regular_conventional_gasoline_price (
	date DATE,
	dollars_per_gallon FLOAT
);

create table us_field_production_of_curde_oil (
	date DATE,
	crude_oil BIGINT
);

create table total_gasoline_by_prime_supplier (
	date DATE,
	thousand_gallons_per_day FLOAT
);