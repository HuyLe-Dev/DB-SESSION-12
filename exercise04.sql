--1 Tự động thêm đuôi email (BEFORE INSERT)
DELIMITER //

CREATE TRIGGER before_insert_employees
BEFORE INSERT ON employees
FOR EACH ROW
BEGIN
    -- Kiểm tra nếu email không kết thúc bằng @company.com
    IF NEW.email NOT LIKE '%@company.com' THEN
        SET NEW.email = CONCAT(NEW.email, '@company.com');
    END IF;
END //

DELIMITER ;

--2 Tự động tạo lương mặc định (AFTER INSERT)

DELIMITER //

CREATE TRIGGER after_insert_employees
AFTER INSERT ON employees
FOR EACH ROW
BEGIN
    -- Chèn lương cơ bản 1tr cho nhân viên vừa tạo (NEW.employee_id)
    INSERT INTO salaries (employee_id, base_salary, bonus)
    VALUES (NEW.employee_id, 10000000, 0.00);
END //

DELIMITER ;

--Trigger 3: Tự động tính giờ làm (BEFORE UPDATE)

DELIMITER //

CREATE TRIGGER before_update_attendance
BEFORE UPDATE ON attendance
FOR EACH ROW
BEGIN
    -- Chỉ tính toán khi check_out_time có dữ liệu
    IF NEW.check_out_time IS NOT NULL THEN
        -- Tính số phút chênh lệch rồi chia cho 60 để ra số giờ
        SET NEW.total_hours = TIMESTAMPDIFF(MINUTE, NEW.check_in_time, NEW.check_out_time) / 60.0;
    END IF;
END //

DELIMITER ;

--check
INSERT INTO departments (department_name) VALUES ('IT Support');

-- Chỉ nhập 'nguyenvanan', mong đợi kết quả là 'nguyenvanan@company.com'
INSERT INTO employees (name, email, phone, hire_date, department_id)
VALUES ('Nguyễn Văn An', 'nguyenvanan', '0987654321', CURDATE(), 1);

-- Kiểm tra kết quả
SELECT * FROM employees; -- Xem email nếu email không kết thúc bằng @company.com => SAI
SELECT * FROM salaries;  -- Xem lương 10tr


-- 1. Nhân viên Check-in lúc 8:00 sáng
INSERT INTO attendance (employee_id, check_in_time)
VALUES (1, '2025-10-25 08:00:00');

-- 2. Nhân viên Check-out lúc 17:30 chiều (Lúc này Trigger 3 sẽ chạy)
UPDATE attendance
SET check_out_time = '2025-10-25 17:30:00'
WHERE employee_id = 1;

-- Kiểm tra kết quả
-- Mong đợi: total_hours = 9.5 (9 tiếng rưỡi)
SELECT * FROM attendance;