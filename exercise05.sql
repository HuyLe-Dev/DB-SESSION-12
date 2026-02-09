ALTER TABLE salary_history DROP FOREIGN KEY salary_history_ibfk_1;
--Tăng lương
DROP PROCEDURE IF EXISTS IncreaseSalary;

DELIMITER //

CREATE PROCEDURE IncreaseSalary(
    IN p_emp_id INT,
    IN p_new_salary DECIMAL(10,2),
    IN p_reason TEXT
)
BEGIN
    -- Khai báo biến
    DECLARE v_old_salary DECIMAL(10,2);
    DECLARE v_count INT DEFAULT 0;

    -- Bắt đầu giao dịch
    START TRANSACTION;

    -- BƯỚC 1: Chỉ đếm để kiểm tra tồn tại
    SELECT COUNT(*) INTO v_count 
    FROM salaries 
    WHERE employee_id = p_emp_id;

    -- Trường hợp 1: Nhân viên không tồn tại
    IF v_count = 0 THEN
        ROLLBACK;
        SELECT 'Lỗi: Nhân viên không tồn tại hoặc chưa có lương cơ bản.' AS message;
    
    -- Trường hợp 2: Nhân viên tồn tại -> Thực hiện update
    ELSE
        -- BƯỚC 2: Lấy lương cũ riêng (Khi đã chắc chắn nhân viên tồn tại)
        SELECT base_salary INTO v_old_salary 
        FROM salaries 
        WHERE employee_id = p_emp_id;

        -- B3: Lưu lịch sử lương cũ vào bảng history
        INSERT INTO salary_history (employee_id, old_salary, new_salary, reason)
        VALUES (p_emp_id, v_old_salary, p_new_salary, p_reason);

        -- B4: Cập nhật lương mới vào bảng salaries
        UPDATE salaries 
        SET base_salary = p_new_salary 
        WHERE employee_id = p_emp_id;

        -- B5: Chốt giao dịch
        COMMIT;
        SELECT 'Thành công: Đã tăng lương và lưu lịch sử.' AS message;
    END IF;

END //

DELIMITER ;

--Xóa nhân viên

DROP PROCEDURE IF EXISTS DeleteEmployee;

DELIMITER //

CREATE PROCEDURE DeleteEmployee(
    IN p_emp_id INT
)
BEGIN
    DECLARE v_emp_exists INT DEFAULT 0;

    -- Bắt đầu giao dịch
    START TRANSACTION;

    -- Kiểm tra xem nhân viên có tồn tại không
    SELECT COUNT(*) INTO v_emp_exists FROM employees WHERE employee_id = p_emp_id;

    IF v_emp_exists = 0 THEN
        -- Không tìm thấy -> Hủy
        ROLLBACK;
        SELECT 'Lỗi: Không tìm thấy nhân viên để xóa.' AS message;
    ELSE
        -- Tìm thấy -> Xóa lần lượt
        -- 1. Xóa lương trước (do có khóa ngoại)
        DELETE FROM salaries WHERE employee_id = p_emp_id;
        
        -- 2. Xóa thông tin chấm công (nếu có, để tránh lỗi khóa ngoại)
        DELETE FROM attendance WHERE employee_id = p_emp_id;

        -- 3. Xóa nhân viên
        DELETE FROM employees WHERE employee_id = p_emp_id;

        -- Chốt giao dịch
        COMMIT;
        SELECT 'Thành công: Đã xóa nhân viên (Lịch sử lương vẫn được giữ).' AS message;
    END IF;

END //

DELIMITER ;

CALL IncreaseSalary(1, 15000.00, 'Tăng lương định kỳ');

CALL DeleteEmployee(1);