#!/usr/bin/env ruby

module Flapjack
  module Gateways
    class JSONAPI < Sinatra::Base
      module Helpers
        module ResourceLinks

          def resource_post_links(klass, id, assoc_name, options)
            assoc_ids, _ = wrapped_link_params(assoc_name)
            halt(err(403, "No link ids")) if assoc_ids.empty?

            singular_klass   = (options[:singular_links]   || {})[assoc_name]
            collection_klass = (options[:collection_links] || {})[assoc_name]

            resource = klass.find_by_id!(id)

            # Not checking for duplication on adding existing to a multiple
            # association, the JSONAPI spec doesn't ask for it
            if !collection_klass.nil?
              associated = collection_klass.find_by_ids!(*assoc_ids)
              resource.send(assoc_name.to_sym).add(*associated)
            elsif !singular_klass.nil?
              halt(err(409, "Association '#{assoc_name}' is already populated")) unless resource.send(assoc_name.to_sym).nil?
              halt(err(409, "Trying to add multiple records to singular association '#{assoc_name}'")) if assoc_ids.size > 1
              associated = singular_klass.find_by_id!(*assoc_ids)
              resource.send("#{assoc_name}=".to_sym, associated)
            else
              # TODO halt
            end
          end

          def resource_get_links(klass, id, assoc_name, options)
            singular_links   = options[:singular_links]   || {}
            collection_links = options[:collection_links] || {}

            assoc_accessor = if collection_links.has_key?(assoc_name)
              :ids
            elsif singular_links.has_key?(assoc_name)
              :id
            else
              # TODO halt
            end

            assoc_ids = klass.find_by_id!(id).send(assoc_name).
                          send(assoc_accessor)

            Flapjack.dump_json(assoc_name => assoc_ids)
          end

          def resource_put_links(klass, id, assoc_name, options)
            assoc_ids, _ = wrapped_link_params(assoc_name)

            resource = klass.find_by_id!(id)

            singular_klass   = (options[:singular_links]   || {})[assoc_name]
            collection_klass = (options[:collection_links] || {})[assoc_name]

            if !collection_klass.nil?
              current_assoc_ids = resource.send(assoc_name.to_sym).ids
              to_remove = current_assoc_ids - assoc_ids
              to_add    = assoc_ids - current_assoc_ids
              tr = to_remove.empty? ? [] : collection_klass.find_by_ids!(*to_remove)
              ta = to_add.empty?    ? [] : collection_klass.find_by_ids!(*to_add)
              resource.send(assoc_name.to_sym).delete(*tr) unless tr.empty?
              resource.send(assoc_name.to_sym).add(*ta) unless ta.empty?
            elsif !singular_klass.nil?
              halt(err(409, "Trying to add multiple records to singular association '#{assoc_name}'")) if assoc_ids.size > 1
              value = assoc_ids.first.nil? ? nil : singular_klass.find_by_id!(assoc_ids.first)
              resource.send("#{assoc_name}=".to_sym, value)
            else
              # TODO halt
            end
          end

          # singular association
          def resource_delete_link(klass, id, assoc_name, assoc_klass)
            resource = klass.find_by_id!(id)
            # validate that the associated record exists
            halt(err(403, "No association '#{assoc_name}' to delete for id '#{resource.id}'")) if resource.send(assoc_name.to_sym).nil?
            resource.send("#{assoc_name}=".to_sym, nil)
          end

          # multiple association
          def resource_delete_links(klass, id, assoc_name, assoc_klass, assoc_ids)
            halt(err(403, "No link ids")) if assoc_ids.empty?

            # validate that the association ids actually exist in the associations
            resource = klass.find_by_id!(id)
            assoc = resource.send(assoc_name.to_sym)
            associated = assoc.find_by_ids!(*assoc_ids)
            assoc.delete(*associated)
          end

        end
      end
    end
  end
end