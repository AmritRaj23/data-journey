CREATE DATABASE IF NOT EXISTS database_name;
USE database_name;
CREATE TABLE IF NOT EXISTS database_name.example_table (
id INT NOT NULL AUTO_INCREMENT,
text_col VARCHAR(50),
int_col INT,
created_at TIMESTAMP,
PRIMARY KEY (id)
);
INSERT INTO database_name.example_table (text_col, int_col, created_at) VALUES
('hello', 0, '2020-01-01 00:00:00'),
('goodbye', 1, NULL),
('name', -987, NOW()),
('other', 2786, '2021-01-01 00:00:00');