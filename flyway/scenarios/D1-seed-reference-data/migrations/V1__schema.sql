CREATE TABLE country (
    code char(2)     PRIMARY KEY,
    name varchar(100) NOT NULL
);

CREATE TABLE order_status (
    code       varchar(20) PRIMARY KEY,
    label      varchar(50) NOT NULL,
    sort_order int         NOT NULL,
    active     boolean     NOT NULL DEFAULT true
);

CREATE TABLE orders (
    id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    country_code char(2)     NOT NULL REFERENCES country (code),
    status       varchar(20) NOT NULL REFERENCES order_status (code)
);
