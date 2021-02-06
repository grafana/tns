package com.example.TianMiao.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.example.TianMiao.model.User;

@Repository
public interface UserRepository extends JpaRepository<User, Long> {

}
