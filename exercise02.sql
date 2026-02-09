--Stored Procedure sp_create_order:

DELIMITER //

DROP PROCEDURE IF EXISTS sp_create_order //

CREATE PROCEDURE sp_create_order(
    IN p_customer_id INT,
    IN p_product_id INT,
    IN p_quantity INT,
    IN p_price DECIMAL(10,2)
)
BEGIN
    DECLARE v_stock INT;
    DECLARE v_order_id INT;

    -- Xử lý lỗi: Nếu có lỗi SQL -> Rollback
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'Lỗi hệ thống! Giao dịch thất bại.' AS message;
    END;

    -- Bắt đầu giao dịch
    START TRANSACTION;

    -- 1. Kiểm tra tồn kho (Dùng FOR UPDATE để khóa dòng dữ liệu, tránh xung đột)
    SELECT stock_quantity INTO v_stock
    FROM inventory
    WHERE product_id = p_product_id
    FOR UPDATE;

    -- Nếu kho không đủ hoặc sản phẩm không tồn tại
    IF v_stock IS NULL OR v_stock < p_quantity THEN
        ROLLBACK;
        SELECT 'Số lượng hàng trong kho không đủ!' AS message;
    ELSE
        -- 2. Thêm đơn hàng mới
        -- (total_amount = qty * price)
        INSERT INTO orders (customer_id, order_date, total_amount, status)
        VALUES (p_customer_id, NOW(), p_quantity * p_price, 'Pending');

        -- 3. Lấy ID đơn hàng vừa tạo
        SET v_order_id = LAST_INSERT_ID();

        -- 4. Thêm vào chi tiết đơn hàng
        INSERT INTO order_items (order_id, product_id, quantity, price)
        VALUES (v_order_id, p_product_id, p_quantity, p_price);

        -- 5. Trừ kho
        UPDATE inventory
        SET stock_quantity = stock_quantity - p_quantity
        WHERE product_id = p_product_id;

        -- 6. Hoàn tất
        COMMIT;
        SELECT 'Tạo đơn hàng thành công!' AS message, v_order_id AS new_order_id;
    END IF;

END //

DELIMITER ;

--Stored Procedure sp_pay_order:

DELIMITER //

DROP PROCEDURE IF EXISTS sp_pay_order //

CREATE PROCEDURE sp_pay_order(
    IN p_order_id INT,
    IN p_payment_method VARCHAR(50)
)
BEGIN
    DECLARE v_status VARCHAR(50);
    DECLARE v_total_amount DECIMAL(10,2);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'Lỗi thanh toán!' AS message;
    END;

    START TRANSACTION;

    -- 1. Kiểm tra trạng thái đơn hàng
    SELECT status, total_amount INTO v_status, v_total_amount
    FROM orders
    WHERE order_id = p_order_id
    FOR UPDATE;

    -- Logic kiểm tra
    IF v_status != 'Pending' THEN
        ROLLBACK;
        SELECT 'Đơn hàng không ở trạng thái chờ thanh toán (Pending)!' AS message;
    ELSE
        -- 2. Thêm bản ghi thanh toán
        INSERT INTO payments (order_id, payment_date, amount, payment_method, status)
        VALUES (p_order_id, NOW(), v_total_amount, p_payment_method, 'Completed');

        -- 3. Cập nhật trạng thái đơn hàng
        UPDATE orders
        SET status = 'Completed'
        WHERE order_id = p_order_id;

        COMMIT;
        SELECT 'Thanh toán thành công!' AS message;
    END IF;

END //

DELIMITER ;

--Stored Procedure sp_cancel_order:

DELIMITER //

DROP PROCEDURE IF EXISTS sp_cancel_order //

CREATE PROCEDURE sp_cancel_order(
    IN p_order_id INT
)
BEGIN
    DECLARE v_status VARCHAR(50);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'Lỗi hủy đơn hàng!' AS message;
    END;

    START TRANSACTION;

    -- 1. Kiểm tra trạng thái đơn hàng
    SELECT status INTO v_status
    FROM orders
    WHERE order_id = p_order_id
    FOR UPDATE;

    IF v_status != 'Pending' THEN
        ROLLBACK;
        SELECT 'Chỉ có thể hủy đơn hàng đang chờ xử lý (Pending)!' AS message;
    ELSE
        -- 2. Hoàn trả số lượng hàng vào kho
        UPDATE inventory i
        JOIN order_items oi ON i.product_id = oi.product_id
        SET i.stock_quantity = i.stock_quantity + oi.quantity
        WHERE oi.order_id = p_order_id;

        -- 3. Xóa các sản phẩm liên quan khỏi order_items
        DELETE FROM order_items
        WHERE order_id = p_order_id;

        -- 4. Cập nhật trạng thái đơn hàng thành Cancelled
        UPDATE orders
        SET status = 'Cancelled'
        WHERE order_id = p_order_id;

        COMMIT;
        SELECT 'Hủy đơn hàng thành công!' AS message;
    END IF;

END //

DELIMITER ;

--TEST---

-- 1. Tạo đơn hàng mới Mua 2 cái Laptop ID=1
CALL sp_create_order(1, 1, 2, 15000000);
-- Kết quả: Thành công, Kho còn 8.

-- 2. Thử tạo đơn hàng Mua 100 cái
CALL sp_create_order(1, 1, 100, 15000000);
-- Kết quả: Báo lỗi không đủ kho.

-- 3. Thanh toán đơn hàng
CALL sp_pay_order(1, 'Credit Card');
-- Kết quả: Trạng thái đơn thành Completed.

-- 4. Hủy đơn hàng vừa thanh toán (ID 1)
CALL sp_cancel_order(1);
-- Kết quả: Báo lỗi vì đơn đã Completed (không phải Pending).

-- 5. Tạo thêm 1 đơn mới để test hủy
CALL sp_create_order(1, 1, 1, 15000000); -- Đơn ID 2
-- Hủy đơn ID 2
CALL sp_cancel_order(2);
-- Kết quả: Thành công, Kho được cộng lại 1 cái.

--TEST---

DROP PROCEDURE IF EXISTS sp_create_order;
DROP PROCEDURE IF EXISTS sp_pay_order;
DROP PROCEDURE IF EXISTS sp_cancel_order;