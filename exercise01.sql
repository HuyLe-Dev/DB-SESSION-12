CREATE DATABASE ecommerce;
USE ecommerce;
-- 1. Bảng customers (Khách hàng)
CREATE TABLE customers (
    customer_id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(20),
    address TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Bảng orders (Đơn hàng)
CREATE TABLE orders (
    order_id INT PRIMARY KEY AUTO_INCREMENT,
    customer_id INT NOT NULL,
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    total_amount DECIMAL(10,2) DEFAULT 0,
    status ENUM('Pending', 'Completed', 'Cancelled') DEFAULT 'Pending',
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE CASCADE
);

-- 3. Bảng products (Sản phẩm)
CREATE TABLE products (
    product_id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(255) NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 4. Bảng order_items (Chi tiết đơn hàng)
CREATE TABLE order_items (
    order_item_id INT PRIMARY KEY AUTO_INCREMENT,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    price DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

-- 5. Bảng inventory (Kho hàng)
CREATE TABLE inventory (
    product_id INT PRIMARY KEY,
    stock_quantity INT NOT NULL CHECK (stock_quantity >= 0),
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE
);

-- 6. Bảng payments (Thanh toán)
CREATE TABLE payments (
    payment_id INT PRIMARY KEY AUTO_INCREMENT,
    order_id INT NOT NULL,
    payment_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    amount DECIMAL(10,2) NOT NULL,
    payment_method ENUM('Credit Card', 'PayPal', 'Bank Transfer', 'Cash') NOT NULL,
    status ENUM('Pending', 'Completed', 'Failed') DEFAULT 'Pending',
    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE
);

-- Dữ liệu bảng products
INSERT INTO products (name, price, description) VALUES
('Laptop Dell', 15000000, 'Laptop văn phòng'),
('iPhone 15', 20000000, 'Điện thoại cao cấp');

-- Dữ liệu bảng inventory
-- Laptop có 10 cái, iPhone có 5 cái
INSERT INTO inventory (product_id, stock_quantity) VALUES
(1, 10),
(2, 5);

-- Dữ liệu bảng customers
INSERT INTO customers (name, email) VALUES
('Nguyen Van A', 'nguyena@email.com');

-- đơn hàng chưa có sản phẩm
INSERT INTO orders (customer_id) VALUES (1);


--1. Trigger BEFORE INSERT (Kiểm tra tồn kho)
DELIMITER //

CREATE TRIGGER check_stock_before_insert
BEFORE INSERT ON order_items
FOR EACH ROW
BEGIN
    DECLARE v_stock INT;

    -- Lấy số lượng tồn kho hiện tại
    SELECT stock_quantity INTO v_stock
    FROM inventory
    WHERE product_id = NEW.product_id;

    -- Kiểm tra: Nếu không có dữ liệu kho hoặc tồn kho < số lượng mua
    IF v_stock IS NULL OR v_stock < NEW.quantity THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Không đủ hàng trong kho để thêm vào đơn hàng!';
    END IF;
END //

DELIMITER ;

--2. Trigger AFTER INSERT (Cập nhật tổng tiền đơn hàng)

DELIMITER //

CREATE TRIGGER update_total_after_insert
AFTER INSERT ON order_items
FOR EACH ROW
BEGIN
    UPDATE orders
    SET total_amount = total_amount + (NEW.quantity * NEW.price)
    WHERE order_id = NEW.order_id;
    
END //

DELIMITER ;

--3. Trigger BEFORE UPDATE (Kiểm tra tồn kho khi sửa số lượng)

DELIMITER //

CREATE TRIGGER check_stock_before_update
BEFORE UPDATE ON order_items
FOR EACH ROW
BEGIN
    DECLARE v_stock INT;

    -- Chỉ kiểm tra nếu số lượng mua tăng lên
    IF NEW.quantity > OLD.quantity THEN
        
        -- Lấy tồn kho hiện tại
        SELECT stock_quantity INTO v_stock
        FROM inventory
        WHERE product_id = NEW.product_id;

        -- So sánh tồn kho với phần chênh lệch (NEW - OLD)
        IF v_stock IS NULL OR v_stock < (NEW.quantity - OLD.quantity) THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Không đủ hàng trong kho để cập nhật số lượng!';
        END IF;
    END IF;
END //

DELIMITER ;

--4. Trigger AFTER UPDATE (Tính lại tổng tiền)

DELIMITER //

CREATE TRIGGER update_total_after_update
AFTER UPDATE ON order_items
FOR EACH ROW
BEGIN
    -- Tính lại tổng tiền và cập nhật
    UPDATE orders
    SET total_amount = (
        SELECT SUM(quantity * price)
        FROM order_items
        WHERE order_id = NEW.order_id
    )
    WHERE order_id = NEW.order_id;
END //

DELIMITER ;

--5. Trigger BEFORE DELETE (Chặn xóa đơn Completed)

DELIMITER //

CREATE TRIGGER prevent_delete_completed_order
BEFORE DELETE ON orders
FOR EACH ROW
BEGIN
    IF OLD.status = 'Completed' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Không thể xóa đơn hàng đã hoàn thành!';
    END IF;
END //

DELIMITER ;

--6. Trigger AFTER DELETE (Hoàn trả kho khi xóa sản phẩm)
DELIMITER //

CREATE TRIGGER restore_stock_after_delete
AFTER DELETE ON order_items
FOR EACH ROW
BEGIN
    -- Cộng lại số lượng đã xóa vào kho
    UPDATE inventory
    SET stock_quantity = stock_quantity + OLD.quantity
    WHERE product_id = OLD.product_id;
    
    UPDATE orders
    SET total_amount = total_amount - (OLD.quantity * OLD.price)
    WHERE order_id = OLD.order_id;
END //

DELIMITER ;

--1. Test Insert (Check kho & Update tiền):
INSERT INTO order_items (order_id, product_id, quantity, price) VALUES (1, 2, 2, 20000000);

--2. Test Insert lỗi
INSERT INTO order_items (order_id, product_id, quantity, price) VALUES (1, 1, 100, 15000000);

--3. Test Update
UPDATE order_items SET quantity = 3 WHERE order_item_id = 1;

--4. Test Delete
DELETE FROM order_items WHERE order_item_id = 1;
SELECT * FROM inventory WHERE product_id = 2;