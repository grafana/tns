package com.grafana.news.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.grafana.news.model.Post;

@Repository
public interface PostRepository extends JpaRepository<Post, Long> {

}
