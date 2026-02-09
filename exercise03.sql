CREATE TABLE IF NOT EXISTS order_logs (
    log_id INT PRIMARY KEY AUTO_INCREMENT,
    order_id INT NOT NULL,
    old_status ENUM('Pending', 'Completed', 'Cancelled'),
    new_status ENUM('Pending', 'Completed', 'Cancelled'),
    log_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE
);

--Kiểm tra số tiền thanh toán (BEFORE INSERT)
DELIMITER //

DROP TRIGGER IF EXISTS before_insert_check_payment //

CREATE TRIGGER before_insert_check_payment
BEFORE INSERT ON payments
FOR EACH ROW
BEGIN
    DECLARE v_total_amount DECIMAL(10,2);

    -- Lấy tổng tiền của đơn hàng tương ứng
    SELECT total_amount INTO v_total_amount
    FROM orders
    WHERE order_id = NEW.order_id;

    -- So sánh số tiền thanh toán (NEW.amount) với tổng tiền đơn hàng
    IF NEW.amount <> v_total_amount THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Lỗi: Số tiền thanh toán không khớp với tổng tiền đơn hàng!';
    END IF;
END //

DELIMITER ;

--Ghi log thay đổi trạng thái (AFTER UPDATE)
DELIMITER //

DROP TRIGGER IF EXISTS after_update_order_status //

CREATE TRIGGER after_update_order_status
AFTER UPDATE ON orders
FOR EACH ROW
BEGIN
    -- Chỉ ghi log nếu trạng thái thực sự thay đổi
    IF OLD.status <> NEW.status THEN
        INSERT INTO order_logs (order_id, old_status, new_status, log_date)
        VALUES (OLD.id, OLD.status, NEW.status, NOW());
    END IF;
END //

DELIMITER ;

--sp_update_order_status_with_payment

DELIMITER //

DROP PROCEDURE IF EXISTS sp_update_order_status_with_payment //

CREATE PROCEDURE sp_update_order_status_with_payment(
    IN p_order_id INT,
    IN p_new_status VARCHAR(50),
    IN p_payment_amount DECIMAL(10,2),
    IN p_payment_method VARCHAR(50)
)
BEGIN
    DECLARE v_current_status VARCHAR(50);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'Giao dịch thất bại! Lỗi hệ thống hoặc sai số tiền thanh toán.' AS message;
    END;

    START TRANSACTION;

    -- 1. Kiểm tra trạng thái hiện tại
    SELECT status INTO v_current_status
    FROM orders
    WHERE order_id = p_order_id
    FOR UPDATE;

    -- Kiểm tra logic: Nếu trạng thái trùng nhau thì không làm gì
    IF v_current_status = p_new_status THEN
        ROLLBACK;
        SELECT 'Trạng thái mới trùng với trạng thái hiện tại.' AS message;
    ELSE
        -- 2. Nếu trạng thái mới là 'Completed', tiến hành thanh toán
        IF p_new_status = 'Completed' THEN
            INSERT INTO payments (order_id, amount, payment_method, status)
            VALUES (p_order_id, p_payment_amount, p_payment_method, 'Completed');
        END IF;

        -- 3. Cập nhật trạng thái đơn hàng
        UPDATE orders
        SET status = p_new_status
        WHERE order_id = p_order_id;

        COMMIT;
        SELECT 'Cập nhật trạng thái và thanh toán thành công!' AS message;
    END IF;

END //

DELIMITER ;

INSERT INTO customers (name, email) VALUES ('Nguyen Van Huy', 'huytester@user.com');

INSERT INTO orders (customer_id, total_amount, status) 
VALUES (LAST_INSERT_ID(), 15000000, 'Pending');

SET @order_id = LAST_INSERT_ID();

CALL sp_update_order_status_with_payment(@order_id, 'Completed', 10000000, 'Credit Card');

CALL sp_update_order_status_with_payment(@order_id, 'Completed', 15000000, 'Credit Card');

DROP TRIGGER IF EXISTS before_insert_check_payment;
DROP TRIGGER IF EXISTS after_update_order_status;
DROP PROCEDURE IF EXISTS sp_update_order_status_with_payment;
DROP TABLE IF EXISTS order_logs;